alter table public.reviews add column package_id uuid references public.packages(id);

update public.reviews r
set package_id = o.package_id
from public.orders o
where o.id = r.order_id and r.package_id is null;

alter table public.reviews alter column package_id set not null;
create index idx_reviews_package_created on public.reviews(package_id, created_at desc);

create or replace function public.prepare_customer_review()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  order_row public.orders%rowtype;
begin
  select * into order_row
  from public.orders
  where id = new.order_id and customer_id = auth.uid() and status = 'delivered';
  if not found then raise exception 'Only delivered orders can be reviewed'; end if;
  new.customer_id := auth.uid();
  new.package_id := order_row.package_id;
  new.vendor_id := order_row.vendor_id;
  return new;
end;
$$;

create trigger reviews_prepare_insert
before insert on public.reviews
for each row execute function public.prepare_customer_review();

drop policy if exists "customers_create_review" on public.reviews;
create policy "customers_create_delivered_order_review"
on public.reviews for insert
with check (
  customer_id = auth.uid()
  and exists (
    select 1 from public.orders o
    where o.id = order_id
      and o.customer_id = auth.uid()
      and o.status = 'delivered'
      and o.package_id = package_id
  )
);

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end;
$$;
