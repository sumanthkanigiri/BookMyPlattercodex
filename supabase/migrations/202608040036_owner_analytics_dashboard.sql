-- Owner analytics dashboard for BookMyPlatter's own catering operations.
-- No vendor marketplace, vendor onboarding, or vendor registration features are introduced here.

create table if not exists public.owner_report_exports (
  id uuid primary key default gen_random_uuid(),
  report_type text not null check (report_type in ('owner_dashboard', 'sales_analytics', 'customer_analytics', 'website_analytics', 'app_analytics', 'booking_analytics', 'marketing_analytics', 'finance_analytics', 'staff_analytics', 'ai_reports')),
  export_format text not null check (export_format in ('csv', 'xlsx', 'pdf', 'print', 'email')),
  date_range tstzrange not null,
  status public.automation_job_status not null default 'scheduled',
  file_url text not null default '',
  emailed_to text[] not null default '{}'::text[],
  requested_by uuid references public.profiles(id) on delete set null,
  scheduled_at timestamptz,
  completed_at timestamptz,
  last_error text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.owner_dashboard_alerts (
  id uuid primary key default gen_random_uuid(),
  alert_type text not null check (alert_type in ('payment_pending', 'expense_spike', 'conversion_drop', 'high_traffic', 'booking_cancelled', 'ai_health')),
  severity text not null default 'info' check (severity in ('info', 'warning', 'critical')),
  title text not null,
  body text not null,
  payload jsonb not null default '{}'::jsonb,
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);

create or replace function public.owner_dashboard_snapshot(p_from timestamptz default date_trunc('day', now()), p_to timestamptz default now())
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_today_start timestamptz := date_trunc('day', now());
  v_tomorrow_start timestamptz := date_trunc('day', now()) + interval '1 day';
  v_month_start timestamptz := date_trunc('month', now());
  v_year_start timestamptz := date_trunc('year', now());
  v_today_revenue numeric := 0;
  v_month_revenue numeric := 0;
  v_year_revenue numeric := 0;
  v_today_expenses numeric := 0;
  v_pending_payments numeric := 0;
  v_orders_today integer := 0;
  v_enquiries_today integer := 0;
  v_bookings_today integer := 0;
  v_visitors_today integer := 0;
  v_payments_today integer := 0;
  v_total_leads integer := 0;
  v_converted_leads integer := 0;
  v_checkout_started integer := 0;
  v_checkout_converted integer := 0;
  v_whatsapp_clicks integer := 0;
  v_call_clicks integer := 0;
  v_new_customers integer := 0;
  v_returning_customers integer := 0;
  v_top_package jsonb := '{}'::jsonb;
  v_top_cuisine jsonb := '{}'::jsonb;
  v_top_event_type jsonb := '{}'::jsonb;
  v_top_city jsonb := '{}'::jsonb;
  v_search_keywords jsonb := '[]'::jsonb;
  v_viewed_packages jsonb := '[]'::jsonb;
  v_campaigns jsonb := '[]'::jsonb;
  v_staff jsonb := '{}'::jsonb;
  v_ai jsonb := '{}'::jsonb;
begin
  if not public.is_admin_staff() then
    raise exception 'owner dashboard access denied';
  end if;

  select coalesce(sum(amount), 0) into v_today_revenue from public.payments where status = 'paid' and created_at >= v_today_start and created_at < v_tomorrow_start;
  select coalesce(sum(amount), 0) into v_month_revenue from public.payments where status = 'paid' and created_at >= v_month_start;
  select coalesce(sum(amount), 0) into v_year_revenue from public.payments where status = 'paid' and created_at >= v_year_start;
  select coalesce(sum(amount + tax_amount), 0) into v_today_expenses from public.finance_expenses where expense_date = current_date;
  select coalesce(sum(amount), 0) into v_pending_payments from public.payments where status in ('pending', 'authorized');
  select count(*) into v_orders_today from public.orders where created_at >= v_today_start and created_at < v_tomorrow_start;
  select count(*) into v_enquiries_today from public.leads where created_at >= v_today_start and created_at < v_tomorrow_start;
  select count(*) into v_bookings_today from public.orders where status in ('placed', 'confirmed', 'preparing', 'out_for_delivery', 'delivered') and created_at >= v_today_start and created_at < v_tomorrow_start;
  select count(*) into v_visitors_today from public.customer_activity where activity_type in ('website_visit', 'app_open') and created_at >= v_today_start and created_at < v_tomorrow_start;
  select count(*) into v_payments_today from public.payments where created_at >= v_today_start and created_at < v_tomorrow_start;
  select count(*), count(*) filter (where status = 'converted') into v_total_leads, v_converted_leads from public.leads where created_at >= p_from and created_at <= p_to;
  select count(*) into v_checkout_started from public.leads where source in ('checkout_started', 'checkout_abandoned') and created_at >= p_from and created_at <= p_to;
  select count(*) into v_checkout_converted from public.leads where source in ('checkout_started', 'checkout_abandoned') and booking_status = 'booked' and created_at >= p_from and created_at <= p_to;
  select count(*) into v_whatsapp_clicks from public.customer_activity where activity_type = 'whatsapp_click' and created_at >= p_from and created_at <= p_to;
  select count(*) into v_call_clicks from public.customer_activity where activity_type = 'call_click' and created_at >= p_from and created_at <= p_to;
  select count(*) into v_new_customers from public.profiles where role = 'customer' and created_at >= p_from and created_at <= p_to;
  select count(*) into v_returning_customers from (select customer_id from public.orders where created_at <= p_to group by customer_id having count(*) > 1) repeat_customers;

  select coalesce(jsonb_build_object('name', p.name, 'orders', count(o.id), 'revenue', coalesce(sum(o.grand_total), 0)), '{}'::jsonb) into v_top_package
  from public.orders o join public.packages p on p.id = o.package_id
  where o.created_at >= p_from and o.created_at <= p_to
  group by p.name order by count(o.id) desc, coalesce(sum(o.grand_total), 0) desc limit 1;

  select coalesce(jsonb_build_object('cuisine', p.cuisine, 'orders', count(o.id)), '{}'::jsonb) into v_top_cuisine
  from public.orders o join public.packages p on p.id = o.package_id
  where o.created_at >= p_from and o.created_at <= p_to
  group by p.cuisine order by count(o.id) desc limit 1;

  select coalesce(jsonb_build_object('event_type', coalesce(l.event_type, 'custom'), 'leads', count(l.id)), '{}'::jsonb) into v_top_event_type
  from public.leads l where l.created_at >= p_from and l.created_at <= p_to group by l.event_type order by count(l.id) desc limit 1;

  select coalesce(jsonb_build_object('location', coalesce(nullif(l.event_location, ''), 'Not captured'), 'leads', count(l.id)), '{}'::jsonb) into v_top_city
  from public.leads l where l.created_at >= p_from and l.created_at <= p_to group by l.event_location order by count(l.id) desc limit 1;

  select coalesce(jsonb_agg(item), '[]'::jsonb) into v_search_keywords from (
    select jsonb_build_object('keyword', search_query, 'count', count(*)) item
    from public.customer_activity
    where activity_type = 'search' and created_at >= p_from and created_at <= p_to and search_query <> ''
    group by search_query order by count(*) desc limit 10
  ) s;

  select coalesce(jsonb_agg(item), '[]'::jsonb) into v_viewed_packages from (
    select jsonb_build_object('package_id', package_id, 'views', count(*)) item
    from public.customer_activity
    where activity_type = 'package_viewed' and created_at >= p_from and created_at <= p_to and package_id is not null
    group by package_id order by count(*) desc limit 10
  ) p;

  select coalesce(jsonb_agg(item), '[]'::jsonb) into v_campaigns from (
    select jsonb_build_object('channel', channel, 'sent', count(*), 'delivered', count(*) filter (where status = 'delivered'), 'failed', count(*) filter (where status = 'failed')) item
    from public.communication_logs where created_at >= p_from and created_at <= p_to group by channel order by count(*) desc
  ) c;

  select jsonb_build_object(
    'attendance_today', (select count(*) from public.staff_attendance where shift_date = current_date),
    'delivery_completed', (select count(*) from public.delivery_trips where status = 'delivered' and updated_at >= v_today_start),
    'kitchen_completed', (select count(*) from public.kitchen_queue where status = 'completed' and updated_at >= v_today_start)
  ) into v_staff;

  select jsonb_build_object(
    'revenue_forecast', round(v_month_revenue * 1.18, 2),
    'sales_forecast', round(greatest(v_converted_leads, 1)::numeric / greatest(v_total_leads, 1) * 100, 2),
    'demand_forecast', (select count(*) from public.company_events where event_at >= now() and event_at < now() + interval '30 days'),
    'customer_insight', case when v_returning_customers > v_new_customers then 'Returning customers are leading demand; prioritize loyalty and reorder campaigns.' else 'New customer acquisition is leading demand; prioritize fast callback and checkout recovery.' end,
    'marketing_suggestion', case when v_whatsapp_clicks >= v_call_clicks then 'WhatsApp engagement is strongest; schedule template campaigns and fast sales follow-up.' else 'Call intent is high; prioritize sales callbacks and staff assignment.' end,
    'business_health', case when v_today_revenue >= v_today_expenses then 'healthy' else 'watch_expenses' end
  ) into v_ai;

  return jsonb_build_object(
    'owner_dashboard', jsonb_build_object('today_revenue', v_today_revenue, 'today_orders', v_orders_today, 'today_enquiries', v_enquiries_today, 'today_bookings', v_bookings_today, 'today_visitors', v_visitors_today, 'today_payments', v_payments_today, 'pending_payments', v_pending_payments, 'today_expenses', v_today_expenses, 'profit_today', v_today_revenue - v_today_expenses, 'monthly_revenue', v_month_revenue, 'yearly_revenue', v_year_revenue),
    'sales_analytics', jsonb_build_object('lead_conversion_percent', round(v_converted_leads::numeric / greatest(v_total_leads, 1) * 100, 2), 'checkout_conversion_percent', round(v_checkout_converted::numeric / greatest(v_checkout_started, 1) * 100, 2), 'whatsapp_clicks', v_whatsapp_clicks, 'call_clicks', v_call_clicks),
    'customer_analytics', jsonb_build_object('new_customers', v_new_customers, 'returning_customers', v_returning_customers, 'average_booking_value', round(v_month_revenue / greatest((select count(*) from public.orders where created_at >= v_month_start), 1), 2), 'favourite_package', v_top_package, 'favourite_cuisine', v_top_cuisine, 'favourite_event_type', v_top_event_type, 'top_location', v_top_city),
    'website_analytics', jsonb_build_object('live_visitors', (select count(*) from public.customer_activity where activity_type = 'website_visit' and created_at >= now() - interval '10 minutes'), 'page_views', (select count(*) from public.customer_activity where activity_type in ('website_visit', 'page_view') and created_at >= p_from and created_at <= p_to), 'search_keywords', v_search_keywords, 'most_viewed_packages', v_viewed_packages),
    'app_analytics', jsonb_build_object('daily_active_users', (select count(distinct customer_id) from public.customer_activity where activity_type = 'app_open' and created_at >= v_today_start), 'app_opens', (select count(*) from public.customer_activity where activity_type = 'app_open' and created_at >= p_from and created_at <= p_to), 'package_views', (select count(*) from public.customer_activity where activity_type = 'package_viewed' and created_at >= p_from and created_at <= p_to), 'cart_events', (select count(*) from public.customer_activity where activity_type = 'cart_added' and created_at >= p_from and created_at <= p_to)),
    'booking_analytics', jsonb_build_object('cancelled_orders', (select count(*) from public.orders where status = 'cancelled' and created_at >= p_from and created_at <= p_to), 'completed_orders', (select count(*) from public.orders where status = 'delivered' and created_at >= p_from and created_at <= p_to), 'top_selling_package', v_top_package),
    'marketing_analytics', jsonb_build_object('communication_reports', v_campaigns),
    'finance_analytics', jsonb_build_object('revenue', v_month_revenue, 'expenses', (select coalesce(sum(amount + tax_amount), 0) from public.finance_expenses where expense_date >= v_month_start::date), 'profit', v_month_revenue - (select coalesce(sum(amount + tax_amount), 0) from public.finance_expenses where expense_date >= v_month_start::date), 'outstanding_payments', v_pending_payments),
    'staff_analytics', v_staff,
    'ai_reports', v_ai
  );
end;
$$;

create index if not exists owner_report_exports_status_idx on public.owner_report_exports(status, scheduled_at);
create index if not exists owner_dashboard_alerts_unresolved_idx on public.owner_dashboard_alerts(severity, created_at desc) where resolved_at is null;

alter table public.owner_report_exports enable row level security;
alter table public.owner_dashboard_alerts enable row level security;

create policy "staff manage owner report exports" on public.owner_report_exports for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "staff manage owner dashboard alerts" on public.owner_dashboard_alerts for all using (public.is_admin_staff()) with check (public.is_admin_staff());

create trigger owner_report_exports_set_updated_at before update on public.owner_report_exports for each row execute function public.set_updated_at();

grant execute on function public.owner_dashboard_snapshot(timestamptz, timestamptz) to authenticated;

do $$
declare
  table_name text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach table_name in array array['owner_report_exports', 'owner_dashboard_alerts'] loop
      if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = table_name) then
        execute format('alter publication supabase_realtime add table public.%I', table_name);
      end if;
    end loop;
  end if;
end;
$$;
