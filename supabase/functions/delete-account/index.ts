import { adminClient, authenticatedUserId, corsPreflight, json } from '../_shared.ts';

Deno.serve(async (request) => {
  const preflight = corsPreflight(request);
  if (preflight) return preflight;
  if (request.method !== 'DELETE') return json({ error: 'Method not allowed' }, 405);
  try {
    const userId = await authenticatedUserId(request);
    const { error } = await adminClient().auth.admin.deleteUser(userId);
    if (error) return json({ error: 'Unable to delete account' }, 500);
    return json({ deleted: true });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Account deletion failed' }, 401);
  }
});
