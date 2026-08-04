-- Prevent privilege escalation through writable profile rows or untrusted Auth metadata.
create or replace function public.current_role()
returns public.app_role
language sql
stable
security definer
set search_path = public
as $$ select role from public.profiles where id = auth.uid() $$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$ select coalesce(public.current_role() in ('admin', 'support'), false) $$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, role, full_name, phone, avatar_url)
  values (
    new.id,
    'customer',
    left(coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''), 'BookMyPlatter Customer'), 80),
    nullif(trim(coalesce(new.phone, new.raw_user_meta_data ->> 'phone')), ''),
    nullif(trim(new.raw_user_meta_data ->> 'avatar_url'), '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke update on public.profiles from authenticated;
grant update (full_name, phone, avatar_url) on public.profiles to authenticated;

create or replace function public.admin_set_user_role(p_user_id uuid, p_role public.app_role)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_role() <> 'admin' then raise exception 'Forbidden'; end if;
  if p_user_id = auth.uid() then raise exception 'Administrators cannot change their own role'; end if;
  update public.profiles set role = p_role, updated_at = now() where id = p_user_id;
  if not found then raise exception 'Profile not found'; end if;
  insert into public.admin_audit_logs(actor_id, action, entity_type, entity_id, new_data)
  values (auth.uid(), 'profile_role_changed', 'profile', p_user_id, jsonb_build_object('role', p_role));
end;
$$;

revoke all on function public.admin_set_user_role(uuid, public.app_role) from public;
grant execute on function public.admin_set_user_role(uuid, public.app_role) to authenticated;

drop policy if exists "public_read_active_banners" on public.banners;
create policy "public_read_scheduled_banners" on public.banners for select
using (
  public.is_admin()
  or (is_active and starts_at <= now() and (ends_at is null or ends_at > now()))
);

-- Review text is customer generated and must remain bounded at both API and DB layers.
alter table public.reviews drop constraint if exists reviews_comment_length_check;
alter table public.reviews add constraint reviews_comment_length_check
check (comment is null or char_length(comment) between 3 and 2000) not valid;

-- Cover the remaining high-frequency application and operations query paths.
create index if not exists idx_profiles_role on public.profiles(role);
create index if not exists idx_menu_items_package_sort on public.menu_items(package_id, sort_order);
create index if not exists idx_banners_active_schedule on public.banners(is_active, starts_at, ends_at);
create index if not exists idx_faq_active_sort on public.frequently_asked_questions(is_active, sort_order);
create index if not exists idx_payments_status_created on public.payments(status, created_at desc);

-- Remove the two bootstrap-only promotional rows; production banners are admin managed.
delete from public.banners
where image_url is null
  and (title, subtitle) in (
    ('Wedding season offers', 'Book verified caterers with transparent per-guest pricing.'),
    ('Office meals simplified', 'Reliable corporate catering for meetings and team events.')
  );
