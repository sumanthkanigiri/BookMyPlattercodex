alter type public.order_status add value if not exists 'packing' after 'preparing';
alter type public.order_status add value if not exists 'arrived_at_venue' after 'out_for_delivery';
alter type public.order_status add value if not exists 'event_started' after 'arrived_at_venue';

create index if not exists idx_order_status_events_timeline
on public.order_status_events(order_id, created_at);
