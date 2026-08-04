create table public.frequently_asked_questions (
  id uuid primary key default gen_random_uuid(),
  question text not null check (char_length(question) between 5 and 300),
  answer text not null check (char_length(answer) between 10 and 5000),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create type public.support_ticket_status as enum ('open', 'in_progress', 'waiting_for_customer', 'resolved', 'closed');

create table public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  subject text not null check (char_length(subject) between 5 and 120),
  message text not null check (char_length(message) between 10 and 2000),
  status public.support_ticket_status not null default 'open',
  resolution text check (resolution is null or char_length(resolution) <= 5000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_support_tickets_customer_created
on public.support_tickets(customer_id, created_at desc);

alter table public.frequently_asked_questions enable row level security;
alter table public.support_tickets enable row level security;

create policy "customers_read_active_faqs"
on public.frequently_asked_questions for select
using (is_active or public.is_admin());

create policy "admins_manage_faqs"
on public.frequently_asked_questions for all
using (public.is_admin()) with check (public.is_admin());

create policy "customers_read_own_support_tickets"
on public.support_tickets for select
using (customer_id = auth.uid() or public.is_admin());

create policy "customers_create_own_support_tickets"
on public.support_tickets for insert
with check (customer_id = auth.uid());

create policy "admins_manage_support_tickets"
on public.support_tickets for update
using (public.is_admin()) with check (public.is_admin());

create trigger frequently_asked_questions_set_updated_at before update on public.frequently_asked_questions
for each row execute function public.set_updated_at();
create trigger support_tickets_set_updated_at before update on public.support_tickets
for each row execute function public.set_updated_at();
