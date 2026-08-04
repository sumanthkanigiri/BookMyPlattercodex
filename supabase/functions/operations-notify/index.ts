import { adminClient, authenticatedUserId, json, readJson } from '../_shared.ts';

type Channel = 'push' | 'sms' | 'email' | 'whatsapp';
type Body = { userId: string; title: string; message: string; channels: Channel[]; orderId?: string };

const clean = (value: string, maximum: number) => value.trim().replaceAll(/\s+/g, ' ').slice(0, maximum);

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  const actorId = await authenticatedUserId(request);
  const supabase = adminClient();
  const { data: actor } = await supabase.from('profiles').select('role').eq('id', actorId).single();
  if (!actor || !['admin', 'support'].includes(actor.role)) return json({ error: 'Forbidden' }, 403);

  const body = await readJson<Body>(request);
  const title = clean(body.title ?? '', 100);
  const message = clean(body.message ?? '', 1000);
  const channels = [...new Set(body.channels ?? [])].filter((channel): channel is Channel => ['push', 'sms', 'email', 'whatsapp'].includes(channel));
  if (!body.userId || title.length < 2 || message.length < 2 || channels.length === 0) return json({ error: 'Recipient, message and channel are required' }, 400);

  const { data: profile } = await supabase.from('profiles').select('phone').eq('id', body.userId).single();
  const { data: authUser } = await supabase.auth.admin.getUserById(body.userId);
  if (!profile) return json({ error: 'Customer not found' }, 404);
  const delivered: Channel[] = [];
  const failures: Record<string, string> = {};

  for (const channel of channels) {
    try {
      if (channel === 'push') {
        const { error } = await supabase.from('notifications').insert({ user_id: body.userId, channel, title, body: message, payload: { orderId: body.orderId } });
        if (error) throw error;
      } else if (channel === 'sms') {
        const key = Deno.env.get('FAST2SMS_API_KEY');
        const sender = Deno.env.get('FAST2SMS_SENDER_ID');
        const phone = String(profile.phone ?? '').replaceAll(/\D/g, '').slice(-10);
        if (!key || !sender || phone.length !== 10) throw new Error('Fast2SMS is not configured or the customer phone is invalid');
        const response = await fetch('https://www.fast2sms.com/dev/bulkV2', { method: 'POST', headers: { authorization: key, 'content-type': 'application/json' }, body: JSON.stringify({ route: 'q', sender_id: sender, message, language: 'english', flash: 0, numbers: phone }) });
        if (!response.ok) throw new Error(`Fast2SMS rejected the message (${response.status})`);
      } else if (channel === 'email') {
        const key = Deno.env.get('RESEND_API_KEY');
        const from = Deno.env.get('EMAIL_FROM');
        const email = authUser.user?.email;
        if (!key || !from || !email) throw new Error('Email delivery is not configured or the customer has no email');
        const response = await fetch('https://api.resend.com/emails', { method: 'POST', headers: { authorization: `Bearer ${key}`, 'content-type': 'application/json' }, body: JSON.stringify({ from, to: [email], subject: title, text: message }) });
        if (!response.ok) throw new Error(`Email provider rejected the message (${response.status})`);
      } else {
        const token = Deno.env.get('WHATSAPP_ACCESS_TOKEN');
        const phoneNumberId = Deno.env.get('WHATSAPP_PHONE_NUMBER_ID');
        const phone = String(profile.phone ?? '').replaceAll(/\D/g, '');
        if (!token || !phoneNumberId || phone.length < 10) throw new Error('WhatsApp is not configured or the customer phone is invalid');
        const response = await fetch(`https://graph.facebook.com/v21.0/${phoneNumberId}/messages`, { method: 'POST', headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' }, body: JSON.stringify({ messaging_product: 'whatsapp', to: phone, type: 'text', text: { body: message } }) });
        if (!response.ok) throw new Error(`WhatsApp rejected the message (${response.status})`);
      }
      delivered.push(channel);
    } catch (error) {
      failures[channel] = error instanceof Error ? error.message : 'Delivery failed';
    }
  }

  await supabase.from('admin_audit_logs').insert({ actor_id: actorId, action: 'customer_notification_sent', entity_type: 'profile', entity_id: body.userId, new_data: { title, channels, delivered, failures, order_id: body.orderId } });
  return json({ delivered, failures }, delivered.length === 0 ? 502 : 200);
});
