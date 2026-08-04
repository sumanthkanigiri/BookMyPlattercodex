import { createClient } from '@supabase/supabase-js';

export function adminClient() {
  const url = Deno.env.get('SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !key) throw new Error('Supabase service configuration is missing');
  return createClient(url, key, { auth: { persistSession: false } });
}

export function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

export async function readJson<T>(request: Request): Promise<T> {
  try {
    return await request.json() as T;
  } catch (_) {
    throw new Error('Invalid JSON request body');
  }
}

export async function authenticatedUserId(request: Request) {
  const authorization = request.headers.get('authorization');
  if (!authorization?.startsWith('Bearer ')) throw new Error('Authentication required');
  const { data, error } = await adminClient().auth.getUser(authorization.slice(7));
  if (error || !data.user) throw new Error('Invalid authentication token');
  return data.user.id;
}

export async function requireStaff(request: Request) {
  const userId = await authenticatedUserId(request);
  const { data, error } = await adminClient()
    .from('profiles')
    .select('role')
    .eq('id', userId)
    .single();
  if (error || !data || !['admin', 'support'].includes(data.role)) {
    throw new Error('Forbidden');
  }
  return userId;
}
