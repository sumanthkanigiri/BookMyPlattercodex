alter table public.orders add column if not exists booking_id uuid not null default gen_random_uuid();
create index if not exists idx_orders_booking on public.orders(booking_id);

alter table public.payments
  add column booking_id uuid,
  add column gateway_payment_id text,
  add column verified_at timestamptz,
  add column failure_code text,
  add column failure_description text,
  add column refunded_amount numeric(10,2) not null default 0 check (refunded_amount >= 0);

update public.payments p
set booking_id = o.booking_id
from public.orders o
where o.id = p.order_id and p.booking_id is null;

alter table public.payments alter column booking_id set not null;
create unique index idx_payments_razorpay_booking_active
on public.payments(booking_id, provider)
where status in ('pending', 'authorized', 'paid');
create index idx_payments_booking_created on public.payments(booking_id, created_at desc);

create policy "customers_read_own_payments"
on public.payments for select
using (exists (
  select 1 from public.orders o
  where o.booking_id = payments.booking_id and o.customer_id = auth.uid()
));
