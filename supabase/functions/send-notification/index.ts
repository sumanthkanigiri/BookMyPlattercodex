import { adminClient, json, readJson } from '../_shared.ts';

type RequestBody = { userId: string; title: string; body: string; channel?: 'push' | 'sms' | 'email' | 'whatsapp'; payload?: Record<string, unknown> };

Deno.serve(async (request) => {
  const body = await readJson<RequestBody>(request);
  const supabase = adminClient();
  const { data, error } = await supabase
    .from('notifications')
    .insert({ user_id: body.userId, title: body.title, body: body.body, channel: body.channel ?? 'push', payload: body.payload ?? {}, sent_at: new Date().toISOString() })
    .select()
    .single();
  if (error) return json({ error: error.message }, 400);
  return json({ notification: data });
});
