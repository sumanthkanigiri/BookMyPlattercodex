create table public.admin_audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid not null references public.profiles(id),
  action text not null check (char_length(action) between 3 and 100),
  entity_type text not null check (char_length(entity_type) between 2 and 80),
  entity_id text not null,
  previous_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);

create index idx_admin_audit_logs_created on public.admin_audit_logs(created_at desc);
create index idx_admin_audit_logs_entity on public.admin_audit_logs(entity_type, entity_id, created_at desc);

alter table public.admin_audit_logs enable row level security;

create policy "staff_read_admin_audit_logs"
on public.admin_audit_logs for select
using (public.is_admin());

revoke insert, update, delete on public.admin_audit_logs from anon, authenticated;
