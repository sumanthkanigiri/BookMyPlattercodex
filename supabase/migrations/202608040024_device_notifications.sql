create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique check (char_length(token) between 20 and 4096),
  platform text not null check (platform in ('android','ios','web')),
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index idx_device_tokens_user on public.device_tokens(user_id, last_seen_at desc);
alter table public.device_tokens enable row level security;
create policy "customers_manage_own_device_tokens" on public.device_tokens for all using (user_id=auth.uid()) with check (user_id=auth.uid());
create or replace function public.register_device_token(p_token text, p_platform text)
returns void language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if char_length(p_token) not between 20 and 4096 or p_platform not in ('android','ios','web') then raise exception 'Invalid device token'; end if;
  delete from public.device_tokens where token=p_token;
  insert into public.device_tokens(user_id,token,platform) values(auth.uid(),p_token,p_platform);
end $$;
revoke all on function public.register_device_token(text,text) from public;
grant execute on function public.register_device_token(text,text) to authenticated;
