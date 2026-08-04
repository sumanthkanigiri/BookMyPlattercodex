import { corsPreflight, json } from '../_shared.ts';
Deno.serve((request) => {
  const preflight = corsPreflight(request); if (preflight) return preflight;
  if (request.method !== 'GET' && request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  return json({
    razorpay: Boolean(Deno.env.get('RAZORPAY_KEY_ID') && Deno.env.get('RAZORPAY_KEY_SECRET')),
    fast2sms: Boolean(Deno.env.get('FAST2SMS_API_KEY') && Deno.env.get('FAST2SMS_SENDER_ID') && Deno.env.get('FAST2SMS_HOOK_SECRET')),
    firebase: Boolean(Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON')),
  });
});
