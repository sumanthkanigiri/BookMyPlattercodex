-- Enterprise AI CRM extensions shared by the customer app, website and admin panel.

-- Broaden lead and staff sources without breaking existing rows.
do $$ begin alter type public.lead_source add value if not exists 'website_visit'; exception when duplicate_object then null; end $$;
do $$ begin alter type public.lead_source add value if not exists 'app_open'; exception when duplicate_object then null; end $$;
do $$ begin alter type public.lead_source add value if not exists 'phone_call'; exception when duplicate_object then null; end $$;
do $$ begin alter type public.lead_source add value if not exists 'google_ads'; exception when duplicate_object then null; end $$;
do $$ begin alter type public.lead_source add value if not exists 'facebook_ads'; exception when duplicate_object then null; end $$;
do $$ begin alter type public.lead_source add value if not exists 'instagram'; exception when duplicate_object then null; end $$;
do $$ begin alter type public.lead_source add value if not exists 'referral'; exception when duplicate_object then null; end $$;
do $$ begin alter type public.lead_source add value if not exists 'qr_code'; exception when duplicate_object then null; end $$;
do $$ begin alter type public.lead_source add value if not exists 'offline'; exception when duplicate_object then null; end $$;
do $$ begin alter type public.lead_source add value if not exists 'walk_in'; exception when duplicate_object then null; end $$;
do $$ begin alter type public.crm_message_status add value if not exists 'read'; exception when duplicate_object then null; end $$;
do $$ begin alter type public.app_role add value if not exists 'operations'; exception when duplicate_object then null; end $$;

create sequence if not exists public.lead_number_seq start with 10001;

alter table public.leads add column if not exists lead_number text;
alter table public.leads add column if not exists first_source text not null default '';
alter table public.leads add column if not exists last_source text not null default '';
alter table public.leads add column if not exists source_campaign text not null default '';
alter table public.leads add column if not exists source_medium text not null default '';
alter table public.leads add column if not exists source_content text not null default '';
alter table public.leads add column if not exists source_term text not null default '';
alter table public.leads add column if not exists ip_address inet;
alter table public.leads add column if not exists location jsonb not null default '{}'::jsonb;
alter table public.leads add column if not exists device_info jsonb not null default '{}'::jsonb;
alter table public.leads add column if not exists last_activity_at timestamptz;

update public.leads
set lead_number = 'BMP-' || lpad(nextval('public.lead_number_seq')::text, 8, '0')
where lead_number is null;

alter table public.leads alter column lead_number set not null;
alter table public.leads add constraint leads_lead_number_unique unique (lead_number);

create or replace function public.assign_lead_number()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.lead_number is null or new.lead_number = '' then
    new.lead_number := 'BMP-' || lpad(nextval('public.lead_number_seq')::text, 8, '0');
  end if;
  return new;
end;
$$;

drop trigger if exists assign_lead_number_trigger on public.leads;
create trigger assign_lead_number_trigger before insert on public.leads for each row execute function public.assign_lead_number();

alter table public.communication_logs add column if not exists read_at timestamptz;
alter table public.communication_logs add column if not exists retry_after_at timestamptz;
alter table public.communication_logs add column if not exists campaign_id uuid;
alter table public.communication_logs add column if not exists delivery_report jsonb not null default '{}'::jsonb;
alter table public.customer_activity add column if not exists browser text not null default '';
alter table public.customer_activity add column if not exists ip_address inet;
alter table public.customer_activity add column if not exists location jsonb not null default '{}'::jsonb;
alter table public.customer_activity add column if not exists source text not null default '';

create table if not exists public.customer_documents (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references public.profiles(id) on delete cascade,
  lead_id uuid references public.leads(id) on delete set null,
  order_id uuid references public.orders(id) on delete set null,
  document_type text not null check (document_type in ('file', 'document', 'invoice', 'quotation', 'payment_receipt', 'menu', 'contract')),
  file_name text not null,
  file_url text not null,
  mime_type text not null default '',
  size_bytes bigint not null default 0 check (size_bytes >= 0),
  uploaded_by uuid references public.profiles(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.call_logs (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid references public.leads(id) on delete set null,
  customer_id uuid references public.profiles(id) on delete set null,
  staff_id uuid references public.profiles(id) on delete set null,
  phone_number text not null,
  direction text not null check (direction in ('inbound', 'outbound')),
  status text not null default 'completed',
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  duration_seconds integer not null default 0 check (duration_seconds >= 0),
  notes text not null default '',
  recording_url text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.ai_marketing_assets (
  id uuid primary key default gen_random_uuid(),
  asset_type text not null check (asset_type in ('blog', 'seo_blog', 'instagram_post', 'facebook_post', 'google_business_post', 'festival_campaign', 'email_campaign', 'sms_campaign', 'whatsapp_campaign', 'push_campaign')),
  title text not null,
  prompt text not null default '',
  content text not null default '',
  seo_title text,
  seo_description text,
  keywords text[] not null default '{}',
  status text not null default 'draft' check (status in ('draft', 'generated', 'scheduled', 'published', 'archived')),
  target_url text,
  publish_at timestamptz,
  published_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.crm_analytics_daily (
  id uuid primary key default gen_random_uuid(),
  metric_date date not null,
  source text not null default 'all',
  city text not null default '',
  leads integer not null default 0 check (leads >= 0),
  converted integer not null default 0 check (converted >= 0),
  revenue numeric(12,2) not null default 0 check (revenue >= 0),
  ad_spend numeric(12,2) not null default 0 check (ad_spend >= 0),
  website_visits integer not null default 0 check (website_visits >= 0),
  app_opens integer not null default 0 check (app_opens >= 0),
  checkout_started integer not null default 0 check (checkout_started >= 0),
  checkout_abandoned integer not null default 0 check (checkout_abandoned >= 0),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(metric_date, source, city)
);

create table if not exists public.crm_heatmap_events (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references public.profiles(id) on delete set null,
  anonymous_id text not null default '',
  page_path text not null,
  element_key text not null,
  event_type text not null check (event_type in ('view', 'click', 'scroll', 'hover', 'submit')),
  x integer,
  y integer,
  viewport_width integer,
  viewport_height integer,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists leads_lead_number_idx on public.leads(lead_number);
create index if not exists leads_attribution_idx on public.leads(first_source, source_campaign, created_at desc);
create index if not exists communication_logs_status_retry_idx on public.communication_logs(status, retry_after_at, created_at desc);
create index if not exists customer_activity_source_idx on public.customer_activity(source, occurred_at desc);
create index if not exists customer_documents_customer_idx on public.customer_documents(customer_id, created_at desc);
create index if not exists call_logs_lead_idx on public.call_logs(lead_id, started_at desc);
create index if not exists ai_marketing_assets_status_idx on public.ai_marketing_assets(asset_type, status, publish_at);
create index if not exists crm_analytics_daily_source_idx on public.crm_analytics_daily(metric_date desc, source, city);
create index if not exists crm_heatmap_events_path_idx on public.crm_heatmap_events(page_path, created_at desc);

alter table public.customer_documents enable row level security;
alter table public.call_logs enable row level security;
alter table public.ai_marketing_assets enable row level security;
alter table public.crm_analytics_daily enable row level security;
alter table public.crm_heatmap_events enable row level security;

drop policy if exists "document visibility" on public.customer_documents;
create policy "document visibility" on public.customer_documents for select using (public.is_admin_staff() or customer_id = auth.uid());
drop policy if exists "staff manage customer documents" on public.customer_documents;
create policy "staff manage customer documents" on public.customer_documents for all using (public.is_admin_staff()) with check (public.is_admin_staff());

drop policy if exists "staff manage call logs" on public.call_logs;
create policy "staff manage call logs" on public.call_logs for all using (public.is_admin_staff()) with check (public.is_admin_staff());
drop policy if exists "customer read own call logs" on public.call_logs;
create policy "customer read own call logs" on public.call_logs for select using (customer_id = auth.uid());

drop policy if exists "staff manage ai marketing assets" on public.ai_marketing_assets;
create policy "staff manage ai marketing assets" on public.ai_marketing_assets for all using (public.is_admin_staff()) with check (public.is_admin_staff());
drop policy if exists "published ai assets are readable" on public.ai_marketing_assets;
create policy "published ai assets are readable" on public.ai_marketing_assets for select using (status = 'published');

drop policy if exists "staff read crm analytics" on public.crm_analytics_daily;
create policy "staff read crm analytics" on public.crm_analytics_daily for select using (public.is_admin_staff());
drop policy if exists "staff manage crm analytics" on public.crm_analytics_daily;
create policy "staff manage crm analytics" on public.crm_analytics_daily for all using (public.is_admin_staff()) with check (public.is_admin_staff());

drop policy if exists "staff read heatmap events" on public.crm_heatmap_events;
create policy "staff read heatmap events" on public.crm_heatmap_events for select using (public.is_admin_staff());
drop policy if exists "public write heatmap events" on public.crm_heatmap_events;
create policy "public write heatmap events" on public.crm_heatmap_events for insert with check (true);

create trigger ai_marketing_assets_set_updated_at before update on public.ai_marketing_assets for each row execute function public.set_updated_at();
create trigger crm_analytics_daily_set_updated_at before update on public.crm_analytics_daily for each row execute function public.set_updated_at();

create or replace function public.capture_enterprise_lead(
  p_source public.lead_source,
  p_customer_name text default '',
  p_mobile text default '',
  p_email text default '',
  p_whatsapp_number text default '',
  p_event_type text default 'custom',
  p_event_date timestamptz default null,
  p_guest_count integer default null,
  p_food_preference text default null,
  p_budget numeric default null,
  p_event_location text default '',
  p_notes text default '',
  p_device_info jsonb default '{}'::jsonb,
  p_location jsonb default '{}'::jsonb,
  p_ip_address inet default null,
  p_attribution jsonb default '{}'::jsonb,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lead uuid;
  v_source_text text := p_source::text;
begin
  select public.record_lead_activity(
    p_source, p_customer_name, p_mobile, p_email, p_whatsapp_number,
    p_event_type, p_event_date, p_guest_count, p_food_preference, p_budget,
    p_event_location, p_notes, 'not_booked', 'pending',
    coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object('attribution', coalesce(p_attribution, '{}'::jsonb))
  ) into v_lead;

  update public.leads
  set first_source = coalesce(nullif(first_source, ''), v_source_text),
      last_source = v_source_text,
      source_campaign = coalesce(nullif(p_attribution->>'campaign', ''), source_campaign),
      source_medium = coalesce(nullif(p_attribution->>'medium', ''), source_medium),
      source_content = coalesce(nullif(p_attribution->>'content', ''), source_content),
      source_term = coalesce(nullif(p_attribution->>'term', ''), source_term),
      ip_address = coalesce(p_ip_address, ip_address),
      location = coalesce(p_location, '{}'::jsonb),
      device_info = coalesce(p_device_info, '{}'::jsonb),
      last_activity_at = now()
  where id = v_lead;

  update public.customer_activity
  set source = v_source_text,
      device_info = coalesce(p_device_info, '{}'::jsonb),
      location = coalesce(p_location, '{}'::jsonb),
      ip_address = p_ip_address
  where id = (
    select id from public.customer_activity
    where lead_id = v_lead
    order by created_at desc
    limit 1
  );

  return v_lead;
end;
$$;

grant execute on function public.capture_enterprise_lead(
  public.lead_source, text, text, text, text, text, timestamptz, integer,
  text, numeric, text, text, jsonb, jsonb, inet, jsonb, jsonb
) to anon, authenticated;

do $$
declare
  table_name text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach table_name in array array['customer_documents', 'call_logs', 'ai_marketing_assets', 'crm_analytics_daily', 'crm_heatmap_events'] loop
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
