-- Company-operated event management. BookMyPlatter owns operations; this is not a vendor marketplace or vendor app.

create table if not exists public.event_types (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  color_hex text not null default '#3C1285',
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.event_types(slug, name, sort_order)
values
  ('wedding', 'Wedding', 10),
  ('birthday', 'Birthday', 20),
  ('corporate', 'Corporate', 30),
  ('housewarming', 'Housewarming', 40),
  ('engagement', 'Engagement', 50),
  ('reception', 'Reception', 60),
  ('naming_ceremony', 'Naming Ceremony', 70),
  ('anniversary', 'Anniversary', 80),
  ('private_party', 'Private Party', 90),
  ('festival_event', 'Festival Event', 100)
on conflict (slug) do update set name = excluded.name, sort_order = excluded.sort_order, updated_at = now();

create table if not exists public.company_events (
  id uuid primary key default gen_random_uuid(),
  event_number text not null unique default ('EVT-' || upper(substr(gen_random_uuid()::text, 1, 8))),
  order_id uuid references public.orders(id) on delete set null,
  lead_id uuid references public.leads(id) on delete set null,
  customer_id uuid references public.profiles(id) on delete set null,
  event_type_id uuid references public.event_types(id) on delete set null,
  event_name text not null default '',
  event_type text not null default 'private_party',
  event_at timestamptz not null,
  ends_at timestamptz,
  venue_name text not null default '',
  venue_address text not null default '',
  guest_count integer not null default 1 check (guest_count > 0),
  food_preference text check (food_preference is null or food_preference in ('veg', 'non_veg', 'mixed')),
  budget numeric(12,2) check (budget is null or budget >= 0),
  status text not null default 'upcoming' check (status in ('draft', 'upcoming', 'active', 'completed', 'cancelled')),
  kitchen_status text not null default 'not_started',
  staff_status text not null default 'unassigned',
  delivery_status text not null default 'unassigned',
  google_calendar_event_id text not null default '',
  notes text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.event_timeline (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.company_events(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  timeline_type text not null check (timeline_type in ('booking', 'lead', 'call', 'whatsapp', 'sms', 'payment', 'invoice', 'review', 'referral', 'kitchen', 'staff', 'delivery', 'support', 'note')),
  title text not null,
  body text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.event_assignments (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.company_events(id) on delete cascade,
  staff_profile_id uuid references public.staff_profiles(id) on delete set null,
  profile_id uuid references public.profiles(id) on delete set null,
  assignment_type text not null check (assignment_type in ('sales', 'kitchen', 'chef', 'captain', 'manager', 'delivery', 'driver')),
  status text not null default 'assigned' check (status in ('assigned', 'accepted', 'in_progress', 'completed', 'cancelled')),
  starts_at timestamptz,
  ends_at timestamptz,
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.event_calendar_connections (
  id uuid primary key default gen_random_uuid(),
  provider text not null check (provider in ('google_calendar', 'ical')),
  calendar_name text not null,
  calendar_id text not null,
  sync_direction text not null default 'push' check (sync_direction in ('push', 'pull', 'two_way')),
  is_active boolean not null default true,
  last_synced_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(provider, calendar_id)
);

create table if not exists public.event_calendar_sync_jobs (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references public.company_events(id) on delete cascade,
  connection_id uuid references public.event_calendar_connections(id) on delete set null,
  status public.automation_job_status not null default 'scheduled',
  attempts integer not null default 0 check (attempts >= 0),
  last_error text not null default '',
  scheduled_at timestamptz not null default now(),
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

create or replace function public.sync_order_company_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event_type_id uuid;
  v_status text;
begin
  select id into v_event_type_id from public.event_types where slug = coalesce(new.event_type, 'private_party') limit 1;
  v_status := case
    when new.status in ('cancelled', 'refunded') then 'cancelled'
    when new.status = 'delivered' then 'completed'
    when new.event_at <= now() then 'active'
    else 'upcoming'
  end;

  insert into public.company_events(
    order_id, customer_id, event_type_id, event_name, event_type, event_at,
    venue_address, guest_count, budget, status, kitchen_status, delivery_status, metadata
  ) values (
    new.id, new.customer_id, v_event_type_id, coalesce(new.event_type, 'Event'),
    coalesce(new.event_type, 'private_party'), new.event_at, new.delivery_address,
    new.guest_count, new.grand_total, v_status,
    case when new.status in ('preparing', 'packing') then new.status::text else 'not_started' end,
    case when new.status in ('out_for_delivery', 'delivered') then new.status::text else 'unassigned' end,
    jsonb_build_object('order_status', new.status, 'package_id', new.package_id)
  )
  on conflict (order_id) do update set
    customer_id = excluded.customer_id,
    event_type_id = excluded.event_type_id,
    event_name = excluded.event_name,
    event_type = excluded.event_type,
    event_at = excluded.event_at,
    venue_address = excluded.venue_address,
    guest_count = excluded.guest_count,
    budget = excluded.budget,
    status = excluded.status,
    kitchen_status = excluded.kitchen_status,
    delivery_status = excluded.delivery_status,
    metadata = company_events.metadata || excluded.metadata,
    updated_at = now();

  insert into public.event_timeline(event_id, actor_id, timeline_type, title, body, metadata)
  select ce.id, new.customer_id, 'booking', 'Order synchronized', 'Company event updated from booking order.', jsonb_build_object('order_id', new.id, 'status', new.status)
  from public.company_events ce
  where ce.order_id = new.id;

  return new;
end;
$$;

drop trigger if exists sync_order_company_event_trigger on public.orders;
create trigger sync_order_company_event_trigger after insert or update of status, event_at, guest_count, delivery_address on public.orders for each row execute function public.sync_order_company_event();

create unique index if not exists company_events_order_unique_idx on public.company_events(order_id);
create index if not exists company_events_event_at_status_idx on public.company_events(event_at, status);
create index if not exists company_events_customer_idx on public.company_events(customer_id, event_at desc);
create index if not exists event_timeline_event_idx on public.event_timeline(event_id, created_at desc);
create index if not exists event_assignments_event_type_idx on public.event_assignments(event_id, assignment_type, status);
create index if not exists event_calendar_sync_jobs_status_idx on public.event_calendar_sync_jobs(status, scheduled_at);

alter table public.event_types enable row level security;
alter table public.company_events enable row level security;
alter table public.event_timeline enable row level security;
alter table public.event_assignments enable row level security;
alter table public.event_calendar_connections enable row level security;
alter table public.event_calendar_sync_jobs enable row level security;

create policy "public read active event types" on public.event_types for select using (is_active);
create policy "staff manage event types" on public.event_types for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "staff manage company events" on public.company_events for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "customers read own company events" on public.company_events for select using (customer_id = auth.uid());
create policy "staff manage event timeline" on public.event_timeline for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "customers read own event timeline" on public.event_timeline for select using (exists (select 1 from public.company_events e where e.id = event_id and e.customer_id = auth.uid()));
create policy "staff manage event assignments" on public.event_assignments for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "assigned staff read assignments" on public.event_assignments for select using (profile_id = auth.uid());
create policy "staff manage calendar connections" on public.event_calendar_connections for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "staff manage calendar sync jobs" on public.event_calendar_sync_jobs for all using (public.is_admin_staff()) with check (public.is_admin_staff());

create trigger event_types_set_updated_at before update on public.event_types for each row execute function public.set_updated_at();
create trigger company_events_set_updated_at before update on public.company_events for each row execute function public.set_updated_at();
create trigger event_assignments_set_updated_at before update on public.event_assignments for each row execute function public.set_updated_at();
create trigger event_calendar_connections_set_updated_at before update on public.event_calendar_connections for each row execute function public.set_updated_at();

do $$
declare
  table_name text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach table_name in array array['event_types', 'company_events', 'event_timeline', 'event_assignments', 'event_calendar_connections', 'event_calendar_sync_jobs'] loop
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
