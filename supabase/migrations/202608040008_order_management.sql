alter table public.orders
  add column event_type text not null default 'custom',
  add column payment_method text not null default 'cod',
  add column delivery_total numeric(10,2) not null default 0 check (delivery_total >= 0),
  add column cancellation_reason text,
  add column cancelled_at timestamptz,
  add column booking_id uuid not null default gen_random_uuid();

alter table public.orders
  add constraint orders_event_type_check
  check (event_type in ('birthday', 'wedding', 'house_warming', 'corporate', 'naming_ceremony', 'engagement', 'anniversary', 'baby_shower', 'festival', 'family_function', 'custom')),
  add constraint orders_payment_method_check
  check (payment_method in ('cod', 'razorpay'));

create index idx_orders_customer_status_event
on public.orders(customer_id, status, event_at desc);

create or replace function public.place_customer_orders(
  p_items jsonb,
  p_coupon_id uuid,
  p_event_at timestamptz,
  p_event_type text,
  p_delivery_area_id uuid,
  p_delivery_address text,
  p_payment_method text,
  p_notes text default null
)
returns setof uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  item jsonb;
  package_row public.packages%rowtype;
  order_id uuid;
  guests integer;
  subtotal_value numeric(10,2);
  discount_value numeric(10,2) := 0;
  tax_value numeric(10,2);
  coupon_row public.coupons%rowtype;
  booking_value uuid := gen_random_uuid();
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Cart is empty';
  end if;
  if p_event_at <= now() then raise exception 'Event time must be in the future'; end if;
  if p_event_type not in ('birthday', 'wedding', 'house_warming', 'corporate', 'naming_ceremony', 'engagement', 'anniversary', 'baby_shower', 'festival', 'family_function', 'custom') then
    raise exception 'Invalid event type';
  end if;
  if p_payment_method not in ('cod', 'razorpay') then raise exception 'Invalid payment method'; end if;

  if p_coupon_id is not null then
    select * into coupon_row from public.coupons
    where id = p_coupon_id and is_active and now() between starts_at and ends_at
      and (usage_limit is null or used_count < usage_limit)
    for update;
    if not found then raise exception 'Coupon is no longer available'; end if;
  end if;

  for item in select value from jsonb_array_elements(p_items)
  loop
    select * into package_row from public.packages
    where id = (item->>'package_id')::uuid and is_active
    for share;
    if not found then raise exception 'Package is unavailable'; end if;

    guests := (item->>'guest_count')::integer;
    if guests < package_row.min_guests or guests > package_row.max_guests then
      raise exception 'Guest count is outside package limits';
    end if;
    subtotal_value := package_row.price_per_guest * guests;
    discount_value := 0;
    if p_coupon_id is not null and subtotal_value >= coupon_row.min_order_amount then
      discount_value := least(
        subtotal_value,
        greatest(
          coalesce(subtotal_value * coupon_row.discount_percent / 100, 0),
          coalesce(coupon_row.discount_amount, 0)
        )
      );
    end if;
    tax_value := round((subtotal_value - discount_value) * 0.05, 2);

    insert into public.orders (
      customer_id, vendor_id, package_id, coupon_id, status, guest_count, booking_id,
      event_at, event_type, delivery_area_id, delivery_address, subtotal,
      discount_total, tax_total, delivery_total, grand_total, payment_method, notes
    ) values (
      auth.uid(), package_row.vendor_id, package_row.id, p_coupon_id,
      case when p_payment_method = 'razorpay' then 'draft'::public.order_status else 'placed'::public.order_status end,
      guests, booking_value,
      p_event_at, p_event_type, p_delivery_area_id, trim(p_delivery_address), subtotal_value,
      discount_value, tax_value, 0, subtotal_value - discount_value + tax_value,
      p_payment_method, nullif(trim(p_notes), '')
    ) returning id into order_id;

    insert into public.order_status_events(order_id, status, message)
    values (
      order_id,
      case when p_payment_method = 'razorpay' then 'draft'::public.order_status else 'placed'::public.order_status end,
      case when p_payment_method = 'razorpay' then 'Awaiting online payment' else 'Order placed successfully' end
    );
    return next order_id;
  end loop;

  if p_coupon_id is not null then
    update public.coupons set used_count = used_count + 1 where id = p_coupon_id;
  end if;
end;
$$;

revoke all on function public.place_customer_orders(jsonb, uuid, timestamptz, text, uuid, text, text, text) from public;
grant execute on function public.place_customer_orders(jsonb, uuid, timestamptz, text, uuid, text, text, text) to authenticated;

create or replace function public.cancel_customer_order(p_order_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.orders
  set status = 'cancelled', cancellation_reason = nullif(trim(p_reason), ''), cancelled_at = now()
  where id = p_order_id and customer_id = auth.uid() and status in ('placed', 'confirmed');
  if not found then raise exception 'Order cannot be cancelled'; end if;
  insert into public.order_status_events(order_id, status, message)
  values (p_order_id, 'cancelled', 'Order cancelled by customer');
end;
$$;

revoke all on function public.cancel_customer_order(uuid, text) from public;
grant execute on function public.cancel_customer_order(uuid, text) to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'orders'
  ) then
    alter publication supabase_realtime add table public.orders;
  end if;
end;
$$;
