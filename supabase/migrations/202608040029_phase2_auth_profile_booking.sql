alter table public.profiles add column if not exists email text;
alter table public.profiles add column if not exists city text not null default '';
alter table public.profiles add column if not exists event_preferences jsonb not null default '[]'::jsonb;
alter table public.profiles add column if not exists favourite_cuisines text[] not null default '{}'::text[];
alter table public.profiles add column if not exists dietary_preferences text[] not null default '{}'::text[];
alter table public.profiles add column if not exists gst_number text;
alter table public.profiles add column if not exists company_name text;
alter table public.profiles add column if not exists anniversary date;
alter table public.profiles add column if not exists birthday date;
alter table public.profiles add column if not exists blocked_at timestamptz;
alter table public.profiles add column if not exists customer_tags text[] not null default '{}'::text[];
alter table public.profiles add column if not exists admin_notes text not null default '';

create unique index if not exists profiles_email_unique_idx
on public.profiles(lower(email)) where email is not null and email <> '';
create index if not exists profiles_city_idx on public.profiles(city) where city <> '';
create index if not exists profiles_tags_idx on public.profiles using gin(customer_tags);

create table if not exists public.customer_events (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  event_name text not null,
  event_type text not null,
  event_at timestamptz not null,
  venue_name text not null default '',
  address_id uuid references public.customer_addresses(id) on delete set null,
  guest_count integer not null check (guest_count > 0),
  special_instructions text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint customer_events_type_check check (event_type in ('wedding','birthday','housewarming','corporate','engagement','reception','naming_ceremony','other'))
);

create table if not exists public.booking_menu_customizations (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references public.profiles(id) on delete set null,
  package_id uuid not null references public.packages(id) on delete cascade,
  event_id uuid references public.customer_events(id) on delete set null,
  guest_count integer not null check (guest_count > 0),
  selected_menu_items jsonb not null default '[]'::jsonb,
  extras jsonb not null default '{}'::jsonb,
  price_snapshot jsonb not null default '{}'::jsonb,
  status text not null default 'draft' check (status in ('draft','saved','converted','abandoned')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists customer_events_customer_date_idx on public.customer_events(customer_id, event_at desc);
create index if not exists customer_events_type_date_idx on public.customer_events(event_type, event_at desc);
create index if not exists booking_menu_customizations_customer_idx on public.booking_menu_customizations(customer_id, updated_at desc);
create index if not exists booking_menu_customizations_package_idx on public.booking_menu_customizations(package_id, updated_at desc);

alter table public.customer_events enable row level security;
alter table public.booking_menu_customizations enable row level security;

create policy "customers_manage_events" on public.customer_events for all
using (customer_id = auth.uid() or public.is_admin())
with check (customer_id = auth.uid() or public.is_admin());

create policy "customers_manage_menu_customizations" on public.booking_menu_customizations for all
using (customer_id = auth.uid() or public.is_admin())
with check (customer_id = auth.uid() or public.is_admin());

create trigger customer_events_set_updated_at
before update on public.customer_events
for each row execute function public.set_updated_at();

create trigger booking_menu_customizations_set_updated_at
before update on public.booking_menu_customizations
for each row execute function public.set_updated_at();

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'customer_events'
     ) then
    alter publication supabase_realtime add table public.customer_events;
  end if;
end;
$$;
