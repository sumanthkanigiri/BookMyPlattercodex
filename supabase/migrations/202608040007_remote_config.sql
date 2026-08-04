create table public.app_config (
  key text primary key,
  value jsonb not null,
  is_public boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.app_config enable row level security;

create policy "public_read_app_config"
on public.app_config for select
using (is_public or public.is_admin());

create policy "admin_manage_app_config"
on public.app_config for all
using (public.is_admin())
with check (public.is_admin());

create trigger app_config_set_updated_at
before update on public.app_config
for each row execute function public.set_updated_at();
