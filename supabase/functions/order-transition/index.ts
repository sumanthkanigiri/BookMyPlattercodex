import { adminClient, authenticatedUserId, corsPreflight, json, readJson } from '../_shared.ts';

type RequestBody = { orderId: string; status: string };
const allowed = new Map<string, string[]>([
  ['draft', ['placed', 'cancelled']],
  ['placed', ['confirmed', 'cancelled']],
  ['confirmed', ['preparing', 'cancelled']],
  ['preparing', ['packing', 'cancelled']],
  ['packing', ['out_for_delivery', 'cancelled']],
  ['out_for_delivery', ['arrived_at_venue']],
  ['arrived_at_venue', ['event_started']],
  ['event_started', ['delivered']],
  ['delivered', ['refunded']],
]);

Deno.serve(async (request) => {
  const preflight = corsPreflight(request);
  if (preflight) return preflight;
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  const actorId = await authenticatedUserId(request);
  const { orderId, status } = await readJson<RequestBody>(request);
  const supabase = adminClient();
  const { data: actor } = await supabase.from('profiles').select('role').eq('id', actorId).single();
  if (!actor || !['admin', 'support'].includes(actor.role)) return json({ error: 'Forbidden' }, 403);
  const { data: order, error } = await supabase.from('orders').select('id,status,customer_id').eq('id', orderId).single();
  if (error || !order) return json({ error: 'Order not found' }, 404);
  if (!allowed.get(order.status)?.includes(status)) return json({ error: 'Invalid order transition' }, 409);

  const { data, error: updateError } = await supabase
    .from('orders')
    .update({ status, updated_at: new Date().toISOString() })
    .eq('id', orderId)
    .select()
    .single();
  if (updateError) return json({ error: updateError.message }, 400);

  await supabase.from('admin_audit_logs').insert({
    actor_id: actorId,
    action: 'order_status_changed',
    entity_type: 'order',
    entity_id: order.id,
    previous_data: { status: order.status },
    new_data: { status },
  });

  await supabase.from('order_status_events').insert({
    order_id: orderId,
    status,
    message: status.replaceAll('_', ' ').replace(/^./, (value) => value.toUpperCase()),
  });

  await supabase.from('notifications').insert({
    user_id: order.customer_id,
    channel: 'push',
    title: 'Order updated',
    body: `Your order is now ${status.replaceAll('_', ' ')}.`,
    payload: { orderId, status },
  });

  return json({ order: data });
});
