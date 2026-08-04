import { adminClient, json, readJson } from '../_shared.ts';

type RequestBody = { code: string; subtotal: number };

Deno.serve(async (request) => {
  const { code, subtotal } = await readJson<RequestBody>(request);
  if (!code || subtotal <= 0) return json({ valid: false, discount: 0 }, 400);

  const supabase = adminClient();
  const { data, error } = await supabase
    .from('coupons')
    .select('*')
    .eq('code', code.trim().toUpperCase())
    .eq('is_active', true)
    .single();

  if (error || !data) return json({ valid: false, discount: 0 });

  const now = Date.now();
  const withinWindow = now >= Date.parse(data.starts_at) && now <= Date.parse(data.ends_at);
  const hasUsage = data.usage_limit === null || data.used_count < data.usage_limit;
  const meetsMinimum = subtotal >= Number(data.min_order_amount);
  if (!withinWindow || !hasUsage || !meetsMinimum) return json({ valid: false, discount: 0 });

  const percentDiscount = data.discount_percent ? subtotal * Number(data.discount_percent) / 100 : 0;
  const amountDiscount = data.discount_amount ? Number(data.discount_amount) : 0;
  const discount = Math.min(subtotal, Math.max(percentDiscount, amountDiscount));
  return json({ valid: true, couponId: data.id, discount });
});
