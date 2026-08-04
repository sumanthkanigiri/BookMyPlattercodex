create table public.customer_preferences (
  customer_id uuid primary key references public.profiles(id) on delete cascade,
  push_notifications boolean not null default true,
  sms_notifications boolean not null default true,
  email_notifications boolean not null default true,
  marketing_notifications boolean not null default false,
  analytics_consent boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.customer_preferences enable row level security;
create policy "customers_manage_own_preferences"
on public.customer_preferences for all
using (customer_id = auth.uid())
with check (customer_id = auth.uid());

create trigger customer_preferences_set_updated_at
before update on public.customer_preferences
for each row execute function public.set_updated_at();

alter table public.orders drop constraint orders_customer_id_fkey;
alter table public.orders alter column customer_id drop not null;
alter table public.orders add constraint orders_customer_id_fkey
  foreign key (customer_id) references public.profiles(id) on delete set null;

alter table public.reviews drop constraint reviews_customer_id_fkey;
alter table public.reviews alter column customer_id drop not null;
alter table public.reviews add constraint reviews_customer_id_fkey
  foreign key (customer_id) references public.profiles(id) on delete set null;
