create or replace function public.reschedule_customer_order(p_order_id uuid, p_event_at timestamptz)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_event_at <= now() + interval '24 hours' then
    raise exception 'Bookings must be scheduled at least 24 hours in advance';
  end if;
  update public.orders
  set event_at = p_event_at, updated_at = now()
  where id = p_order_id
    and customer_id = auth.uid()
    and status in ('placed', 'confirmed')
    and event_at > now() + interval '24 hours';
  if not found then raise exception 'Booking cannot be rescheduled'; end if;

  insert into public.order_status_events(order_id, status, message)
  select id, status, 'Event rescheduled to ' || to_char(p_event_at at time zone 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM')
  from public.orders where id = p_order_id;
end;
$$;

revoke all on function public.reschedule_customer_order(uuid, timestamptz) from public;
grant execute on function public.reschedule_customer_order(uuid, timestamptz) to authenticated;
