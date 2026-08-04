import { createClient } from '@supabase/supabase-js';

export const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'POST, DELETE, OPTIONS',
};

export function corsPreflight(request: Request) {
  return request.method === 'OPTIONS'
    ? new Response(null, { status: 204, headers: corsHeaders })
    : null;
}

export function adminClient() {
  const url = Deno.env.get('SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !key) throw new Error('Supabase service configuration is missing');
  return createClient(url, key, { auth: { persistSession: false } });
}

export function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
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

function base64Url(value: Uint8Array | string) {
  const bytes = typeof value === 'string' ? new TextEncoder().encode(value) : value;
  return btoa(String.fromCharCode(...bytes)).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}

async function firebaseAccessToken(serviceAccount: Record<string, string>) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64Url(JSON.stringify({ iss: serviceAccount.client_email, scope: 'https://www.googleapis.com/auth/firebase.messaging', aud: serviceAccount.token_uri, iat: now, exp: now + 3600 }));
  const pem = serviceAccount.private_key.replace(/-----[^-]+-----/g, '').replaceAll(/\s/g, '');
  const keyBytes = Uint8Array.from(atob(pem), (value) => value.charCodeAt(0));
  const key = await crypto.subtle.importKey('pkcs8', keyBytes, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const unsigned = `${header}.${claims}`;
  const signature = new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned)));
  const response = await fetch(serviceAccount.token_uri, { method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: `${unsigned}.${base64Url(signature)}` }) });
  if (!response.ok) throw new Error('Firebase authorization failed');
  return (await response.json()).access_token as string;
}

export async function sendFirebasePush(userId: string, title: string, body: string, data: Record<string, string> = {}) {
  const raw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
  if (!raw) throw new Error('Firebase service account is not configured');
  const serviceAccount = JSON.parse(raw) as Record<string, string>;
  const { data: rows, error } = await adminClient().from('device_tokens').select('id,token').eq('user_id', userId);
  if (error) throw error;
  if (!rows?.length) return 0;
  const accessToken = await firebaseAccessToken(serviceAccount);
  let delivered = 0;
  for (const row of rows) {
    const response = await fetch(`https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`, { method: 'POST', headers: { authorization: `Bearer ${accessToken}`, 'content-type': 'application/json' }, body: JSON.stringify({ message: { token: row.token, notification: { title, body }, data } }) });
    if (response.ok) delivered += 1;
    else if (response.status === 404 || response.status === 400) await adminClient().from('device_tokens').delete().eq('id', row.id);
  }
  return delivered;
}
