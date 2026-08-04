alter table public.packages
  add column package_type text not null default 'veg',
  add column cuisine text not null default 'Multi-cuisine',
  add column event_types text[] not null default '{}',
  add column popularity_score integer not null default 0 check (popularity_score >= 0),
  add column search_vector tsvector generated always as (
    to_tsvector('english', coalesce(name, '') || ' ' || coalesce(description, '') || ' ' || coalesce(cuisine, ''))
  ) stored;

alter table public.packages
  add constraint packages_type_check
  check (package_type in ('veg', 'non_veg', 'platter_box'));

update public.packages
set package_type = case when is_veg then 'veg' else 'non_veg' end
where package_type = 'veg';

create index idx_packages_discovery
on public.packages(package_type, price_per_guest, rating desc)
where is_active;

create index idx_packages_event_types
on public.packages using gin(event_types);

create index idx_packages_search on public.packages using gin(search_vector);

create table public.package_views (
  customer_id uuid not null references public.profiles(id) on delete cascade,
  package_id uuid not null references public.packages(id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key (customer_id, package_id)
);

create index idx_package_views_customer_recent
on public.package_views(customer_id, viewed_at desc);

alter table public.package_views enable row level security;
create policy "customers_read_own_package_views"
on public.package_views for select using (customer_id = auth.uid());

create or replace function public.record_package_view(p_package_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.packages
  set popularity_score = popularity_score + 1
  where id = p_package_id and is_active;
  if auth.uid() is not null then
    insert into public.package_views(customer_id, package_id, viewed_at)
    values (auth.uid(), p_package_id, now())
    on conflict (customer_id, package_id)
    do update set viewed_at = excluded.viewed_at;
  end if;
end;
$$;

grant execute on function public.record_package_view(uuid) to anon, authenticated;
