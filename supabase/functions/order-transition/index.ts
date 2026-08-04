import { adminClient, json, readJson } from '../_shared.ts';

type RequestBody = { orderId: string; status: string };
const allowed = new Map<string, string[]>([
  ['draft', ['placed', 'cancelled']],
  ['placed', ['confirmed', 'cancelled']],
  ['confirmed', ['preparing', 'cancelled']],
  ['preparing', ['out_for_delivery', 'cancelled']],
  ['out_for_delivery', ['delivered']],
  ['delivered', ['refunded']],
]);

Deno.serve(async (request) => {
  const { orderId, status } = await readJson<RequestBody>(request);
  const supabase = adminClient();
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

  await supabase.from('notifications').insert({
    user_id: order.customer_id,
    channel: 'push',
    title: 'Order updated',
    body: `Your order is now ${status.replaceAll('_', ' ')}.`,
    payload: { orderId, status },
  });

  return json({ order: data });
});
