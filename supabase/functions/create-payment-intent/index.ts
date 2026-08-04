import { adminClient, authenticatedUserId, corsPreflight, json, readJson } from '../_shared.ts';

type RequestBody = { orderId: string };

Deno.serve(async (request) => {
  const preflight = corsPreflight(request);
  if (preflight) return preflight;
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  try {
    const customerId = await authenticatedUserId(request);
    const { orderId } = await readJson<RequestBody>(request);
    if (!orderId) return json({ error: 'orderId is required' }, 400);

    const keyId = Deno.env.get('RAZORPAY_KEY_ID');
    const keySecret = Deno.env.get('RAZORPAY_KEY_SECRET');
    if (!keyId || !keySecret) return json({ error: 'Payment provider is unavailable' }, 503);

    const supabase = adminClient();
    const { data: selectedOrder, error: orderError } = await supabase
      .from('orders')
      .select('id,booking_id')
      .eq('id', orderId)
      .eq('customer_id', customerId)
      .single();
    if (orderError || !selectedOrder) return json({ error: 'Order not found' }, 404);

    const { data: orders, error: ordersError } = await supabase
      .from('orders')
      .select('id,grand_total')
      .eq('booking_id', selectedOrder.booking_id)
      .eq('customer_id', customerId);
    if (ordersError || !orders?.length) return json({ error: 'Booking not found' }, 404);
    const amount = orders.reduce((sum, order) => sum + Number(order.grand_total), 0);
    const amountPaise = Math.round(amount * 100);

    const existing = await supabase
      .from('payments')
      .select('provider_reference,amount,status')
      .eq('booking_id', selectedOrder.booking_id)
      .eq('provider', 'razorpay')
      .in('status', ['pending', 'authorized', 'paid'])
      .maybeSingle();
    if (existing.data) {
      if (existing.data.status === 'paid') {
        return json({ error: 'This booking is already paid' }, 409);
      }
      return json({
        keyId,
        razorpayOrderId: existing.data.provider_reference,
        amountPaise: Math.round(Number(existing.data.amount) * 100),
        currency: 'INR',
      });
    }

    const razorpayResponse = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: {
        authorization: `Basic ${btoa(`${keyId}:${keySecret}`)}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        amount: amountPaise,
        currency: 'INR',
        receipt: selectedOrder.booking_id,
        notes: { booking_id: selectedOrder.booking_id, customer_id: customerId },
      }),
    });
    if (!razorpayResponse.ok) return json({ error: 'Unable to initialize payment' }, 502);
    const razorpayOrder = await razorpayResponse.json();

    const { error: paymentError } = await supabase.from('payments').insert({
      order_id: selectedOrder.id,
      booking_id: selectedOrder.booking_id,
      provider: 'razorpay',
      provider_reference: razorpayOrder.id,
      amount,
      status: 'pending',
    });
    if (paymentError) return json({ error: 'Unable to persist payment' }, 500);
    return json({ keyId, razorpayOrderId: razorpayOrder.id, amountPaise, currency: 'INR' });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Payment initialization failed' }, 401);
  }
});
