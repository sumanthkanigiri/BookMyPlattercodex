insert into public.app_config(key, value, is_public)
values (
  'checkout_settings',
  '{"cod_enabled":false,"tax_percent":5,"delivery_charge":0,"minimum_lead_hours":24}'::jsonb,
  true
)
on conflict (key) do nothing;

create or replace function public.best_customer_coupon(p_subtotal numeric)
returns table(coupon_id uuid, code text, discount numeric)
language sql
stable
security invoker
set search_path = public
as $$
  select
    c.id,
    c.code,
    least(
      p_subtotal,
      greatest(
        coalesce(p_subtotal * c.discount_percent / 100, 0),
        coalesce(c.discount_amount, 0)
      )
    )::numeric as discount
  from public.coupons c
  where p_subtotal > 0
    and c.is_active
    and now() between c.starts_at and c.ends_at
    and p_subtotal >= c.min_order_amount
    and (c.usage_limit is null or c.used_count < c.usage_limit)
  order by discount desc, c.ends_at
  limit 1;
$$;

grant execute on function public.best_customer_coupon(numeric) to anon, authenticated;

create or replace function public.enforce_checkout_settings()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  settings jsonb;
  tax_percent numeric;
  delivery_charge numeric;
  lead_hours integer;
begin
  select value into settings from public.app_config where key = 'checkout_settings';
  if settings is null then raise exception 'Checkout is temporarily unavailable'; end if;
  if new.payment_method = 'cod' and not coalesce((settings->>'cod_enabled')::boolean, false) then
    raise exception 'Cash on delivery is currently unavailable';
  end if;
  lead_hours := greatest(coalesce((settings->>'minimum_lead_hours')::integer, 24), 0);
  if new.event_at < now() + make_interval(hours => lead_hours) then
    raise exception 'Event does not meet the minimum booking lead time';
  end if;
  tax_percent := greatest(coalesce((settings->>'tax_percent')::numeric, 0), 0);
  delivery_charge := case
    when exists (select 1 from public.orders where booking_id = new.booking_id) then 0
    else greatest(coalesce((settings->>'delivery_charge')::numeric, 0), 0)
  end;
  new.tax_total := round((new.subtotal - new.discount_total) * tax_percent / 100, 2);
  new.delivery_total := delivery_charge;
  new.grand_total := new.subtotal - new.discount_total + new.tax_total + new.delivery_total;
  return new;
end;
$$;

create trigger orders_enforce_checkout_settings
before insert on public.orders
for each row execute function public.enforce_checkout_settings();
