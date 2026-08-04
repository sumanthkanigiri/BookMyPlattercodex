import { adminClient, corsPreflight, json, readJson, requireStaff, sendFirebasePush } from '../_shared.ts';

type RequestBody = { userId: string; title: string; body: string; channel?: 'push' | 'sms' | 'email' | 'whatsapp'; payload?: Record<string, unknown> };

Deno.serve(async (request) => {
  const preflight = corsPreflight(request);
  if (preflight) return preflight;
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  try {
    await requireStaff(request);
  } catch (_) {
    return json({ error: 'Forbidden' }, 403);
  }
  const body = await readJson<RequestBody>(request);
  if (!body.userId || !body.title?.trim() || !body.body?.trim()) {
    return json({ error: 'userId, title, and body are required' }, 400);
  }
  const supabase = adminClient();
  const { data, error } = await supabase
    .from('notifications')
    .insert({ user_id: body.userId, title: body.title, body: body.body, channel: body.channel ?? 'push', payload: body.payload ?? {}, sent_at: new Date().toISOString() })
    .select()
    .single();
  if (error) return json({ error: error.message }, 400);
  if ((body.channel ?? 'push') === 'push') {
    const stringData = Object.fromEntries(Object.entries(body.payload ?? {}).map(([key, value]) => [key, String(value)]));
    await sendFirebasePush(body.userId, body.title.trim(), body.body.trim(), stringData);
  }
  return json({ notification: data });
});
