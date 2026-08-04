create table public.banners (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  subtitle text not null,
  image_url text,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.customer_addresses (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  label text not null,
  line1 text not null,
  line2 text,
  area_id uuid not null references public.areas(id),
  landmark text,
  latitude numeric(10,7),
  longitude numeric(10,7),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.favorites (
  customer_id uuid not null references public.profiles(id) on delete cascade,
  package_id uuid not null references public.packages(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (customer_id, package_id)
);

create table public.order_status_events (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  status public.order_status not null,
  message text not null,
  created_at timestamptz not null default now()
);

create index idx_customer_addresses_customer on public.customer_addresses(customer_id);
create index idx_favorites_package on public.favorites(package_id);
create index idx_order_status_events_order on public.order_status_events(order_id, created_at desc);

alter table public.banners enable row level security;
alter table public.customer_addresses enable row level security;
alter table public.favorites enable row level security;
alter table public.order_status_events enable row level security;

create policy "public_read_active_banners" on public.banners for select using (is_active and (ends_at is null or ends_at > now()));
create policy "admin_manage_banners" on public.banners for all using (public.is_admin()) with check (public.is_admin());

create policy "customers_manage_addresses" on public.customer_addresses for all using (customer_id = auth.uid() or public.is_admin()) with check (customer_id = auth.uid() or public.is_admin());
create policy "customers_manage_favorites" on public.favorites for all using (customer_id = auth.uid() or public.is_admin()) with check (customer_id = auth.uid() or public.is_admin());
create policy "order_events_participants_read" on public.order_status_events for select using (exists (select 1 from public.orders o where o.id = order_id and (o.customer_id = auth.uid() or public.is_admin())));
create policy "admin_insert_order_events" on public.order_status_events for insert with check (public.is_admin());

create trigger customer_addresses_set_updated_at
before update on public.customer_addresses
for each row execute function public.set_updated_at();

insert into public.banners (title, subtitle) values
  ('Wedding season offers', 'Book verified caterers with transparent per-guest pricing.'),
  ('Office meals simplified', 'Reliable corporate catering for meetings and team events.')
on conflict do nothing;
