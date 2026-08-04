-- Enterprise module foundations for kitchen, inventory, purchase, finance, delivery,
-- staff ERP, customer support, loyalty, business intelligence, AI and automation.

-- Shared ERP types.
do $$ begin create type public.enterprise_approval_status as enum ('draft', 'requested', 'approved', 'rejected', 'ordered', 'received', 'paid', 'cancelled'); exception when duplicate_object then null; end $$;
do $$ begin create type public.enterprise_priority as enum ('low', 'medium', 'high', 'urgent'); exception when duplicate_object then null; end $$;
do $$ begin create type public.delivery_trip_status as enum ('assigned', 'en_route', 'arrived', 'delivered', 'failed', 'cancelled'); exception when duplicate_object then null; end $$;
do $$ begin create type public.support_ticket_status as enum ('open', 'in_progress', 'waiting_for_customer', 'resolved', 'closed'); exception when duplicate_object then null; end $$;
do $$ begin alter type public.support_ticket_status add value if not exists 'refunded'; exception when duplicate_object then null; end $$;
do $$ begin create type public.automation_job_status as enum ('scheduled', 'running', 'success', 'failed', 'paused'); exception when duplicate_object then null; end $$;

create table if not exists public.kitchen_recipes (
  id uuid primary key default gen_random_uuid(),
  package_id uuid references public.packages(id) on delete cascade,
  menu_item_id uuid references public.menu_items(id) on delete cascade,
  recipe_name text not null,
  serving_size integer not null default 1 check (serving_size > 0),
  instructions text not null default '',
  prep_minutes integer not null default 0 check (prep_minutes >= 0),
  cook_minutes integer not null default 0 check (cook_minutes >= 0),
  chef_notes text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.raw_materials (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  category text not null default 'general',
  unit text not null default 'kg',
  current_stock numeric(12,3) not null default 0 check (current_stock >= 0),
  minimum_stock numeric(12,3) not null default 0 check (minimum_stock >= 0),
  reorder_quantity numeric(12,3) not null default 0 check (reorder_quantity >= 0),
  expiry_date date,
  preferred_vendor_id uuid,
  cost_per_unit numeric(12,2) not null default 0 check (cost_per_unit >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.recipe_ingredients (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references public.kitchen_recipes(id) on delete cascade,
  material_id uuid not null references public.raw_materials(id) on delete restrict,
  quantity_per_serving numeric(12,4) not null check (quantity_per_serving > 0),
  wastage_percent numeric(5,2) not null default 0 check (wastage_percent between 0 and 100),
  created_at timestamptz not null default now(),
  unique(recipe_id, material_id)
);

create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  material_id uuid not null references public.raw_materials(id) on delete restrict,
  movement_type text not null check (movement_type in ('purchase', 'consumption', 'wastage', 'adjustment', 'return')),
  quantity numeric(12,3) not null,
  unit_cost numeric(12,2) not null default 0 check (unit_cost >= 0),
  order_id uuid references public.orders(id) on delete set null,
  purchase_order_id uuid references public.purchase_orders(id) on delete set null,
  reason text not null default '',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.vendor_profiles (
  id uuid primary key default gen_random_uuid(),
  vendor_name text not null,
  contact_name text not null default '',
  phone text not null default '',
  email text not null default '',
  gst_number text not null default '',
  address text not null default '',
  rating numeric(2,1) check (rating is null or rating between 1 and 5),
  payment_terms text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$ begin
  alter table public.raw_materials add constraint raw_materials_preferred_vendor_fk foreign key (preferred_vendor_id) references public.vendor_profiles(id) on delete set null;
exception when duplicate_object then null; end $$;

create table if not exists public.purchase_requests (
  id uuid primary key default gen_random_uuid(),
  request_number text not null unique,
  requested_by uuid references public.profiles(id) on delete set null,
  status public.enterprise_approval_status not null default 'requested',
  priority public.enterprise_priority not null default 'medium',
  needed_by date,
  notes text not null default '',
  approved_by uuid references public.profiles(id) on delete set null,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.purchase_request_items (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.purchase_requests(id) on delete cascade,
  material_id uuid not null references public.raw_materials(id) on delete restrict,
  quantity numeric(12,3) not null check (quantity > 0),
  estimated_unit_cost numeric(12,2) not null default 0 check (estimated_unit_cost >= 0),
  created_at timestamptz not null default now()
);

create table if not exists public.vendor_quotations (
  id uuid primary key default gen_random_uuid(),
  request_id uuid references public.purchase_requests(id) on delete set null,
  vendor_id uuid not null references public.vendor_profiles(id) on delete restrict,
  quotation_number text not null default '',
  quoted_total numeric(12,2) not null default 0 check (quoted_total >= 0),
  valid_until date,
  status public.enterprise_approval_status not null default 'requested',
  attachment_url text,
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.goods_received_notes (
  id uuid primary key default gen_random_uuid(),
  grn_number text not null unique,
  purchase_order_id uuid references public.purchase_orders(id) on delete set null,
  vendor_id uuid references public.vendor_profiles(id) on delete set null,
  received_by uuid references public.profiles(id) on delete set null,
  received_at timestamptz not null default now(),
  status public.enterprise_approval_status not null default 'received',
  notes text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.finance_invoices (
  id uuid primary key default gen_random_uuid(),
  invoice_number text not null unique,
  order_id uuid references public.orders(id) on delete set null,
  customer_id uuid references public.profiles(id) on delete set null,
  invoice_type text not null check (invoice_type in ('invoice', 'credit_note', 'debit_note', 'vendor_bill', 'salary_slip')),
  taxable_amount numeric(12,2) not null default 0 check (taxable_amount >= 0),
  gst_amount numeric(12,2) not null default 0 check (gst_amount >= 0),
  total_amount numeric(12,2) generated always as (taxable_amount + gst_amount) stored,
  status public.payment_status not null default 'pending',
  due_date date,
  paid_at timestamptz,
  pdf_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.finance_ledger_entries (
  id uuid primary key default gen_random_uuid(),
  entry_date date not null default current_date,
  account text not null,
  entry_type text not null check (entry_type in ('income', 'expense', 'tax', 'salary', 'vendor_payment', 'cash', 'bank')),
  debit numeric(12,2) not null default 0 check (debit >= 0),
  credit numeric(12,2) not null default 0 check (credit >= 0),
  reference_type text not null default '',
  reference_id uuid,
  notes text not null default '',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  check (debit > 0 or credit > 0)
);

create table if not exists public.delivery_drivers (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references public.profiles(id) on delete set null,
  full_name text not null,
  phone text not null,
  license_number text not null default '',
  is_active boolean not null default true,
  current_latitude numeric(10,7),
  current_longitude numeric(10,7),
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.delivery_vehicles (
  id uuid primary key default gen_random_uuid(),
  registration_number text not null unique,
  vehicle_type text not null default 'bike',
  capacity_kg numeric(10,2) not null default 0 check (capacity_kg >= 0),
  fuel_type text not null default 'petrol',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.delivery_trips (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  driver_id uuid references public.delivery_drivers(id) on delete set null,
  vehicle_id uuid references public.delivery_vehicles(id) on delete set null,
  status public.delivery_trip_status not null default 'assigned',
  route_polyline text,
  eta_at timestamptz,
  otp_code text,
  otp_verified_at timestamptz,
  fuel_cost numeric(10,2) not null default 0 check (fuel_cost >= 0),
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.staff_departments (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.staff_profiles (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references public.profiles(id) on delete cascade,
  department_id uuid references public.staff_departments(id) on delete set null,
  employee_code text not null unique,
  designation text not null default '',
  joining_date date,
  salary_monthly numeric(12,2) not null default 0 check (salary_monthly >= 0),
  permissions jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.staff_leave_requests (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.staff_profiles(id) on delete cascade,
  leave_type text not null default 'casual',
  starts_on date not null,
  ends_on date not null,
  status public.enterprise_approval_status not null default 'requested',
  reason text not null default '',
  approved_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_on >= starts_on)
);

alter table public.support_tickets add column if not exists ticket_type text not null default 'support';
alter table public.support_tickets add column if not exists priority public.enterprise_priority not null default 'medium';
alter table public.support_tickets add column if not exists resolution_due_at timestamptz;
alter table public.support_tickets add column if not exists resolved_at timestamptz;

create table if not exists public.support_timeline (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  message text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  transaction_type text not null check (transaction_type in ('credit', 'debit', 'refund', 'reward', 'gift_card')),
  amount numeric(12,2) not null check (amount > 0),
  balance_after numeric(12,2) not null default 0,
  reference_type text not null default '',
  reference_id uuid,
  notes text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.membership_levels (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  min_points integer not null default 0 check (min_points >= 0),
  benefits jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.bi_metric_snapshots (
  id uuid primary key default gen_random_uuid(),
  metric_date date not null,
  metric_group text not null,
  metric_key text not null,
  metric_value numeric(14,4) not null default 0,
  dimensions jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(metric_date, metric_group, metric_key, dimensions)
);

create table if not exists public.ai_insights (
  id uuid primary key default gen_random_uuid(),
  insight_type text not null check (insight_type in ('demand_forecast', 'sales_prediction', 'menu_recommendation', 'pricing_recommendation', 'customer_segmentation', 'marketing_suggestion', 'business_report', 'risk_alert')),
  title text not null,
  summary text not null,
  confidence numeric(5,2) check (confidence is null or confidence between 0 and 100),
  source_metrics jsonb not null default '{}'::jsonb,
  recommendation jsonb not null default '{}'::jsonb,
  status text not null default 'open' check (status in ('open', 'accepted', 'dismissed', 'implemented')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.automation_jobs (
  id uuid primary key default gen_random_uuid(),
  job_key text not null unique,
  job_type text not null check (job_type in ('daily_report', 'weekly_report', 'monthly_report', 'backup', 'health_monitoring', 'database_monitoring', 'error_monitoring', 'performance_monitoring')),
  status public.automation_job_status not null default 'scheduled',
  schedule_cron text not null default '',
  last_run_at timestamptz,
  next_run_at timestamptz,
  last_error text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists kitchen_recipes_package_idx on public.kitchen_recipes(package_id, is_active);
create index if not exists raw_materials_low_stock_idx on public.raw_materials(is_active, current_stock, minimum_stock);
create index if not exists raw_materials_expiry_idx on public.raw_materials(expiry_date) where expiry_date is not null;
create index if not exists inventory_movements_material_idx on public.inventory_movements(material_id, created_at desc);
create index if not exists purchase_requests_status_idx on public.purchase_requests(status, needed_by);
create index if not exists finance_invoices_status_idx on public.finance_invoices(status, due_date);
create index if not exists finance_ledger_entries_date_idx on public.finance_ledger_entries(entry_date desc, entry_type);
create index if not exists delivery_trips_status_eta_idx on public.delivery_trips(status, eta_at);
create index if not exists staff_profiles_department_idx on public.staff_profiles(department_id, is_active);
create index if not exists support_timeline_ticket_idx on public.support_timeline(ticket_id, created_at desc);
create index if not exists wallet_transactions_customer_idx on public.wallet_transactions(customer_id, created_at desc);
create index if not exists bi_metric_snapshots_group_idx on public.bi_metric_snapshots(metric_date desc, metric_group, metric_key);
create index if not exists ai_insights_status_idx on public.ai_insights(insight_type, status, created_at desc);
create index if not exists automation_jobs_status_idx on public.automation_jobs(status, next_run_at);

alter table public.kitchen_recipes enable row level security;
alter table public.raw_materials enable row level security;
alter table public.recipe_ingredients enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.vendor_profiles enable row level security;
alter table public.purchase_requests enable row level security;
alter table public.purchase_request_items enable row level security;
alter table public.vendor_quotations enable row level security;
alter table public.goods_received_notes enable row level security;
alter table public.finance_invoices enable row level security;
alter table public.finance_ledger_entries enable row level security;
alter table public.delivery_drivers enable row level security;
alter table public.delivery_vehicles enable row level security;
alter table public.delivery_trips enable row level security;
alter table public.staff_departments enable row level security;
alter table public.staff_profiles enable row level security;
alter table public.staff_leave_requests enable row level security;
alter table public.support_timeline enable row level security;
alter table public.wallet_transactions enable row level security;
alter table public.membership_levels enable row level security;
alter table public.bi_metric_snapshots enable row level security;
alter table public.ai_insights enable row level security;
alter table public.automation_jobs enable row level security;

-- Staff can operate the ERP; customers can read only their own financial, delivery, support and wallet surfaces.
create policy "staff manage kitchen recipes" on public.kitchen_recipes for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "staff manage raw materials" on public.raw_materials for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "staff manage recipe ingredients" on public.recipe_ingredients for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "staff manage inventory movements" on public.inventory_movements for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "staff manage vendor profiles" on public.vendor_profiles for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "staff manage purchase requests" on public.purchase_requests for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "staff manage purchase request items" on public.purchase_request_items for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "staff manage vendor quotations" on public.vendor_quotations for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "staff manage goods received" on public.goods_received_notes for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "staff manage finance invoices" on public.finance_invoices for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "customers read own finance invoices" on public.finance_invoices for select using (customer_id = auth.uid());
create policy "staff manage finance ledger" on public.finance_ledger_entries for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "staff manage delivery drivers" on public.delivery_drivers for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "staff manage delivery vehicles" on public.delivery_vehicles for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "staff manage delivery trips" on public.delivery_trips for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "customers read own delivery trips" on public.delivery_trips for select using (exists (select 1 from public.orders o where o.id = order_id and o.customer_id = auth.uid()));
create policy "staff manage departments" on public.staff_departments for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "staff manage staff profiles" on public.staff_profiles for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "staff read own profile" on public.staff_profiles for select using (profile_id = auth.uid());
create policy "staff manage leave requests" on public.staff_leave_requests for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "staff manage support timeline" on public.support_timeline for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "customers read own support timeline" on public.support_timeline for select using (exists (select 1 from public.support_tickets t where t.id = ticket_id and t.customer_id = auth.uid()));
create policy "staff manage wallet transactions" on public.wallet_transactions for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "customers read own wallet transactions" on public.wallet_transactions for select using (customer_id = auth.uid());
create policy "public read active membership levels" on public.membership_levels for select using (is_active);
create policy "staff manage membership levels" on public.membership_levels for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "staff manage bi metrics" on public.bi_metric_snapshots for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "staff manage ai insights" on public.ai_insights for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "staff manage automation jobs" on public.automation_jobs for all using (public.is_admin_staff()) with check (public.is_admin_staff());

create or replace function public.calculate_order_ingredients(p_order_id uuid)
returns table(material_id uuid, material_name text, required_quantity numeric, unit text)
language sql
stable
security definer
set search_path = public
as $$
  select
    rm.id,
    rm.name,
    sum(ri.quantity_per_serving * o.guest_count * (1 + ri.wastage_percent / 100.0))::numeric(12,3) as required_quantity,
    rm.unit
  from public.orders o
  join public.kitchen_recipes kr on kr.package_id = o.package_id and kr.is_active
  join public.recipe_ingredients ri on ri.recipe_id = kr.id
  join public.raw_materials rm on rm.id = ri.material_id
  where o.id = p_order_id
    and (public.is_admin_staff() or o.customer_id = auth.uid())
  group by rm.id, rm.name, rm.unit;
$$;

create or replace function public.apply_order_inventory_consumption(p_order_id uuid, p_actor uuid default auth.uid())
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  item record;
begin
  if not public.is_admin_staff() then
    raise exception 'Forbidden';
  end if;

  for item in select * from public.calculate_order_ingredients(p_order_id) loop
    update public.raw_materials
    set current_stock = greatest(0, current_stock - item.required_quantity),
        updated_at = now()
    where id = item.material_id;

    insert into public.inventory_movements(material_id, movement_type, quantity, order_id, reason, created_by)
    values (item.material_id, 'consumption', -item.required_quantity, p_order_id, 'Automatic order consumption', p_actor);
  end loop;
end;
$$;

grant execute on function public.calculate_order_ingredients(uuid) to authenticated;
grant execute on function public.apply_order_inventory_consumption(uuid, uuid) to authenticated;

do $$
declare
  table_name text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach table_name in array array[
      'kitchen_recipes', 'raw_materials', 'inventory_movements', 'vendor_profiles',
      'purchase_requests', 'vendor_quotations', 'goods_received_notes', 'finance_invoices',
      'finance_ledger_entries', 'delivery_drivers', 'delivery_vehicles', 'delivery_trips',
      'staff_profiles', 'staff_leave_requests', 'support_timeline', 'wallet_transactions',
      'membership_levels', 'bi_metric_snapshots', 'ai_insights', 'automation_jobs'
    ] loop
      if not exists (
        select 1 from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = table_name
      ) then
        execute format('alter publication supabase_realtime add table public.%I', table_name);
      end if;
    end loop;
  end if;
end;
$$;
