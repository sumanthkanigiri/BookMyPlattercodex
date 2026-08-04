import { adminClient, authenticatedUserId, json, readJson } from '../_shared.ts';

type RequestBody = {
  razorpayOrderId: string;
  razorpayPaymentId: string;
  razorpaySignature: string;
};

function hex(bytes: ArrayBuffer) {
  return [...new Uint8Array(bytes)].map((value) => value.toString(16).padStart(2, '0')).join('');
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  try {
    const customerId = await authenticatedUserId(request);
    const body = await readJson<RequestBody>(request);
    const secret = Deno.env.get('RAZORPAY_KEY_SECRET');
    if (!secret) return json({ error: 'Payment provider is unavailable' }, 503);
    if (!body.razorpayOrderId || !body.razorpayPaymentId || !body.razorpaySignature) {
      return json({ error: 'Incomplete payment response' }, 400);
    }

    const key = await crypto.subtle.importKey(
      'raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
    );
    const signature = hex(await crypto.subtle.sign(
      'HMAC', key, new TextEncoder().encode(`${body.razorpayOrderId}|${body.razorpayPaymentId}`),
    ));
    if (signature !== body.razorpaySignature.toLowerCase()) {
      return json({ error: 'Payment signature verification failed' }, 400);
    }

    const supabase = adminClient();
    const { data: payment, error } = await supabase
      .from('payments')
      .select('id,booking_id,orders!inner(customer_id)')
      .eq('provider_reference', body.razorpayOrderId)
      .eq('orders.customer_id', customerId)
      .single();
    if (error || !payment) return json({ error: 'Payment record not found' }, 404);

    await supabase.from('payments').update({
      status: 'paid',
      gateway_payment_id: body.razorpayPaymentId,
      verified_at: new Date().toISOString(),
    }).eq('id', payment.id);
    await supabase.from('orders').update({ status: 'placed' }).eq('booking_id', payment.booking_id);
    await supabase.from('notifications').insert({
      user_id: customerId,
      channel: 'push',
      title: 'Payment successful',
      body: 'Your BookMyPlatter booking payment was verified.',
      payload: { booking_id: payment.booking_id },
    });
    return json({ verified: true, bookingId: payment.booking_id });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Payment verification failed' }, 401);
  }
});
