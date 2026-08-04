-- Enterprise ERP surfaces for the BookMyPlatter admin command center.
-- These tables are shared by the customer app, website and admin panel through Supabase realtime.

do $$ begin alter type public.app_role add value if not exists 'kitchen'; exception when duplicate_object then null; end $$;
do $$ begin alter type public.app_role add value if not exists 'sales'; exception when duplicate_object then null; end $$;
do $$ begin alter type public.app_role add value if not exists 'manager'; exception when duplicate_object then null; end $$;
do $$ begin alter type public.app_role add value if not exists 'driver'; exception when duplicate_object then null; end $$;

do $$ begin
  create type public.admin_task_status as enum ('open', 'in_progress', 'blocked', 'done', 'cancelled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.admin_task_priority as enum ('low', 'medium', 'high', 'urgent');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.kitchen_queue_status as enum ('queued', 'prep', 'cooking', 'packing', 'ready', 'dispatched', 'completed', 'blocked');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.marketing_campaign_status as enum ('draft', 'scheduled', 'running', 'paused', 'completed', 'failed');
exception when duplicate_object then null; end $$;

create table if not exists public.admin_tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(trim(title)) between 3 and 160),
  description text,
  module text not null default 'crm',
  status public.admin_task_status not null default 'open',
  priority public.admin_task_priority not null default 'medium',
  assigned_to uuid references public.profiles(id) on delete set null,
  related_order_id uuid references public.orders(id) on delete set null,
  related_lead_id uuid references public.leads(id) on delete set null,
  due_at timestamptz,
  completed_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.staff_attendance (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.profiles(id) on delete cascade,
  work_date date not null default current_date,
  check_in_at timestamptz,
  check_out_at timestamptz,
  status text not null default 'present',
  latitude numeric(10, 7),
  longitude numeric(10, 7),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (staff_id, work_date)
);

create table if not exists public.finance_expenses (
  id uuid primary key default gen_random_uuid(),
  expense_date date not null default current_date,
  category text not null,
  vendor_name text,
  amount numeric(12, 2) not null check (amount >= 0),
  tax_amount numeric(12, 2) not null default 0 check (tax_amount >= 0),
  payment_status public.payment_status not null default 'pending',
  related_order_id uuid references public.orders(id) on delete set null,
  created_by uuid references public.profiles(id) on delete set null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  po_number text not null unique,
  vendor_name text not null,
  order_date date not null default current_date,
  expected_delivery_at timestamptz,
  status text not null default 'draft',
  subtotal numeric(12, 2) not null default 0 check (subtotal >= 0),
  tax_total numeric(12, 2) not null default 0 check (tax_total >= 0),
  grand_total numeric(12, 2) generated always as (subtotal + tax_total) stored,
  related_order_id uuid references public.orders(id) on delete set null,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.kitchen_queue (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  station text not null default 'main_kitchen',
  status public.kitchen_queue_status not null default 'queued',
  chef_id uuid references public.profiles(id) on delete set null,
  prep_starts_at timestamptz,
  ready_by timestamptz,
  blockers text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (order_id, station)
);

create table if not exists public.marketing_campaigns (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 3 and 160),
  channel text not null check (channel in ('sms', 'whatsapp', 'push', 'email', 'instagram', 'facebook', 'google_business')),
  status public.marketing_campaign_status not null default 'draft',
  audience_filter jsonb not null default '{}'::jsonb,
  template_id uuid references public.notification_templates(id) on delete set null,
  scheduled_at timestamptz,
  sent_count integer not null default 0 check (sent_count >= 0),
  delivered_count integer not null default 0 check (delivered_count >= 0),
  failed_count integer not null default 0 check (failed_count >= 0),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


create table if not exists public.website_seo_pages (
  id uuid primary key default gen_random_uuid(),
  path text not null unique,
  title text not null,
  meta_description text not null default '',
  canonical_url text,
  open_graph jsonb not null default '{}'::jsonb,
  json_ld jsonb not null default '{}'::jsonb,
  is_indexable boolean not null default true,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.admin_saved_reports (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  report_type text not null,
  filters jsonb not null default '{}'::jsonb,
  schedule_cron text,
  recipients text[] not null default '{}',
  is_active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_admin_tasks_status_due on public.admin_tasks(status, due_at);
create index if not exists idx_admin_tasks_assigned on public.admin_tasks(assigned_to, status);
create index if not exists idx_staff_attendance_date on public.staff_attendance(work_date, staff_id);
create index if not exists idx_finance_expenses_date on public.finance_expenses(expense_date, payment_status);
create index if not exists idx_purchase_orders_status_delivery on public.purchase_orders(status, expected_delivery_at);
create index if not exists idx_kitchen_queue_status_ready on public.kitchen_queue(status, ready_by);
create index if not exists idx_marketing_campaigns_channel_status on public.marketing_campaigns(channel, status, scheduled_at);
create index if not exists idx_website_seo_pages_indexable on public.website_seo_pages(is_indexable, path);
create index if not exists idx_admin_saved_reports_type on public.admin_saved_reports(report_type, is_active);

alter table public.admin_tasks enable row level security;
alter table public.staff_attendance enable row level security;
alter table public.finance_expenses enable row level security;
alter table public.purchase_orders enable row level security;
alter table public.kitchen_queue enable row level security;
alter table public.marketing_campaigns enable row level security;
alter table public.website_seo_pages enable row level security;
alter table public.admin_saved_reports enable row level security;

create policy "admins_manage_admin_tasks" on public.admin_tasks for all using (public.is_admin()) with check (public.is_admin());
create policy "staff_read_own_tasks" on public.admin_tasks for select using (assigned_to = auth.uid());
create policy "admins_manage_staff_attendance" on public.staff_attendance for all using (public.is_admin()) with check (public.is_admin());
create policy "staff_read_own_attendance" on public.staff_attendance for select using (staff_id = auth.uid());
create policy "admins_manage_finance_expenses" on public.finance_expenses for all using (public.is_admin()) with check (public.is_admin());
create policy "admins_manage_purchase_orders" on public.purchase_orders for all using (public.is_admin()) with check (public.is_admin());
create policy "admins_manage_kitchen_queue" on public.kitchen_queue for all using (public.is_admin()) with check (public.is_admin());
create policy "kitchen_read_queue" on public.kitchen_queue for select using (public.current_role()::text in ('kitchen', 'admin', 'support'));
create policy "admins_manage_marketing_campaigns" on public.marketing_campaigns for all using (public.is_admin()) with check (public.is_admin());
create policy "public_read_indexable_website_seo_pages" on public.website_seo_pages for select using (is_indexable);
create policy "admins_manage_website_seo_pages" on public.website_seo_pages for all using (public.is_admin()) with check (public.is_admin());
create policy "admins_manage_saved_reports" on public.admin_saved_reports for all using (public.is_admin()) with check (public.is_admin());

create trigger set_admin_tasks_updated_at before update on public.admin_tasks for each row execute function public.set_updated_at();
create trigger set_staff_attendance_updated_at before update on public.staff_attendance for each row execute function public.set_updated_at();
create trigger set_finance_expenses_updated_at before update on public.finance_expenses for each row execute function public.set_updated_at();
create trigger set_purchase_orders_updated_at before update on public.purchase_orders for each row execute function public.set_updated_at();
create trigger set_kitchen_queue_updated_at before update on public.kitchen_queue for each row execute function public.set_updated_at();
create trigger set_marketing_campaigns_updated_at before update on public.marketing_campaigns for each row execute function public.set_updated_at();
create trigger set_website_seo_pages_updated_at before update on public.website_seo_pages for each row execute function public.set_updated_at();
create trigger set_admin_saved_reports_updated_at before update on public.admin_saved_reports for each row execute function public.set_updated_at();

do $$
declare
  table_name text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach table_name in array array['website_seo_pages', 'admin_tasks', 'kitchen_queue', 'marketing_campaigns', 'finance_expenses', 'purchase_orders'] loop
      if not exists (
        select 1
        from pg_publication_tables
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
