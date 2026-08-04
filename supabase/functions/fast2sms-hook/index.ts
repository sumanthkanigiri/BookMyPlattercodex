import { corsPreflight, json } from '../_shared.ts';
import { Webhook } from 'standardwebhooks';
type HookPayload = { user?: { phone?: string }; sms?: { otp?: string } };
Deno.serve(async (request) => {
  const preflight = corsPreflight(request); if (preflight) return preflight;
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  const secret = Deno.env.get('FAST2SMS_HOOK_SECRET');
  if (!secret) return json({ error: 'Hook is not configured' }, 503);
  const raw = await request.text();
  let payload: HookPayload;
  try { payload = new Webhook(secret).verify(raw, request.headers) as HookPayload; }
  catch (_) { return json({ error: 'Invalid hook signature' }, 403); }
  const phone = String(payload.user?.phone ?? '').replaceAll(/\D/g, '').slice(-10);
  const otp = String(payload.sms?.otp ?? '');
  const key = Deno.env.get('FAST2SMS_API_KEY');
  const sender = Deno.env.get('FAST2SMS_SENDER_ID');
  if (!key || !sender || phone.length !== 10 || !/^\d{6}$/.test(otp)) return json({ error: 'SMS configuration or payload is invalid' }, 400);
  const response = await fetch('https://www.fast2sms.com/dev/bulkV2', { method: 'POST', headers: { authorization: key, 'content-type': 'application/json' }, body: JSON.stringify({ route: 'dlt', sender_id: sender, message: `Your BookMyPlatter verification code is ${otp}. It expires shortly.`, language: 'english', numbers: phone }) });
  if (!response.ok) return json({ error: 'SMS provider rejected the request' }, 502);
  return json({ delivered: true });
});
