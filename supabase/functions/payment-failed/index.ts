import { adminClient, authenticatedUserId, json, readJson } from '../_shared.ts';

type RequestBody = { orderId: string; code?: string; description?: string };

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  try {
    const customerId = await authenticatedUserId(request);
    const body = await readJson<RequestBody>(request);
    const supabase = adminClient();
    const { data: order } = await supabase
      .from('orders')
      .select('booking_id')
      .eq('id', body.orderId)
      .eq('customer_id', customerId)
      .single();
    if (!order) return json({ error: 'Order not found' }, 404);
    await supabase.from('payments').update({
      status: 'failed',
      failure_code: body.code?.slice(0, 100),
      failure_description: body.description?.slice(0, 500),
    }).eq('booking_id', order.booking_id).eq('status', 'pending');
    return json({ recorded: true });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Unable to record failure' }, 401);
  }
});
