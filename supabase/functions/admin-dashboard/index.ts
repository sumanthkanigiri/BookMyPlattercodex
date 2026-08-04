import { adminClient, json } from '../_shared.ts';

Deno.serve(async () => {
  const supabase = adminClient();
  const [orders, vendors, users] = await Promise.all([
    supabase.from('orders').select('id,grand_total,status', { count: 'exact', head: false }),
    supabase.from('vendors').select('id', { count: 'exact', head: true }),
    supabase.from('profiles').select('id', { count: 'exact', head: true }),
  ]);

  if (orders.error) return json({ error: orders.error.message }, 400);
  if (vendors.error) return json({ error: vendors.error.message }, 400);
  if (users.error) return json({ error: users.error.message }, 400);

  const revenue = (orders.data ?? []).reduce((sum, order) => sum + Number(order.grand_total), 0);
  const byStatus = (orders.data ?? []).reduce<Record<string, number>>((acc, order) => {
    acc[order.status] = (acc[order.status] ?? 0) + 1;
    return acc;
  }, {});

  return json({
    orderCount: orders.count ?? 0,
    vendorCount: vendors.count ?? 0,
    userCount: users.count ?? 0,
    revenue,
    byStatus,
  });
});
