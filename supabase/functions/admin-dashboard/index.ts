import { adminClient, corsPreflight, json, requireStaff } from '../_shared.ts';

Deno.serve(async (request) => {
  const preflight = corsPreflight(request);
  if (preflight) return preflight;
  try {
    await requireStaff(request);
  } catch (_) {
    return json({ error: 'Forbidden' }, 403);
  }
  const supabase = adminClient();
  const [orders, users] = await Promise.all([
    supabase.from('orders').select('id,grand_total,status', { count: 'exact', head: false }),
    supabase.from('profiles').select('id', { count: 'exact', head: true }),
  ]);

  if (orders.error) return json({ error: orders.error.message }, 400);
  if (users.error) return json({ error: users.error.message }, 400);

  const revenue = (orders.data ?? []).reduce((sum, order) => sum + Number(order.grand_total), 0);
  const byStatus = (orders.data ?? []).reduce<Record<string, number>>((acc, order) => {
    acc[order.status] = (acc[order.status] ?? 0) + 1;
    return acc;
  }, {});

  return json({
    orderCount: orders.count ?? 0,
    userCount: users.count ?? 0,
    revenue,
    byStatus,
  });
});
