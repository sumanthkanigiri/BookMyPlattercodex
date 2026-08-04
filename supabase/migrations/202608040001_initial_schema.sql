create extension if not exists "uuid-ossp";
create extension if not exists pgcrypto;

create type public.app_role as enum ('customer', 'vendor', 'delivery_partner', 'support', 'admin');
create type public.order_status as enum ('draft', 'placed', 'confirmed', 'preparing', 'out_for_delivery', 'delivered', 'cancelled', 'refunded');
create type public.payment_status as enum ('pending', 'authorized', 'paid', 'failed', 'refunded');
create type public.notification_channel as enum ('push', 'sms', 'email', 'whatsapp');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.app_role not null default 'customer',
  full_name text not null,
  phone text unique,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.cities (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.areas (
  id uuid primary key default gen_random_uuid(),
  city_id uuid not null references public.cities(id) on delete cascade,
  name text not null,
  slug text not null,
  pincode text,
  is_active boolean not null default true,
  unique(city_id, slug)
);

create table public.vendors (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id),
  name text not null,
  slug text not null unique,
  description text not null,
  city_id uuid not null references public.cities(id),
  is_verified boolean not null default false,
  is_active boolean not null default true,
  rating numeric(3,2) not null default 0 check (rating between 0 and 5),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  description text not null,
  image_url text,
  sort_order integer not null default 0,
  is_active boolean not null default true
);

create table public.packages (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  category_id uuid not null references public.categories(id),
  name text not null,
  slug text not null unique,
  description text not null,
  min_guests integer not null check (min_guests > 0),
  max_guests integer not null check (max_guests >= min_guests),
  price_per_guest numeric(10,2) not null check (price_per_guest >= 0),
  image_url text,
  is_veg boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.menu_items (
  id uuid primary key default gen_random_uuid(),
  package_id uuid not null references public.packages(id) on delete cascade,
  name text not null,
  course text not null,
  description text,
  is_veg boolean not null default true,
  sort_order integer not null default 0
);

create table public.coupons (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  description text not null,
  discount_percent numeric(5,2) check (discount_percent between 0 and 100),
  discount_amount numeric(10,2) check (discount_amount >= 0),
  min_order_amount numeric(10,2) not null default 0,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  usage_limit integer,
  used_count integer not null default 0,
  is_active boolean not null default true,
  check (ends_at > starts_at),
  check (discount_percent is not null or discount_amount is not null)
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id),
  vendor_id uuid not null references public.vendors(id),
  package_id uuid not null references public.packages(id),
  coupon_id uuid references public.coupons(id),
  status public.order_status not null default 'draft',
  guest_count integer not null check (guest_count > 0),
  event_at timestamptz not null,
  delivery_area_id uuid not null references public.areas(id),
  delivery_address text not null,
  subtotal numeric(10,2) not null check (subtotal >= 0),
  discount_total numeric(10,2) not null default 0 check (discount_total >= 0),
  tax_total numeric(10,2) not null default 0 check (tax_total >= 0),
  grand_total numeric(10,2) not null check (grand_total >= 0),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  provider text not null,
  provider_reference text not null unique,
  status public.payment_status not null default 'pending',
  amount numeric(10,2) not null check (amount >= 0),
  currency text not null default 'INR',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  channel public.notification_channel not null,
  title text not null,
  body text not null,
  payload jsonb not null default '{}'::jsonb,
  sent_at timestamptz,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete cascade,
  customer_id uuid not null references public.profiles(id),
  vendor_id uuid not null references public.vendors(id),
  rating integer not null check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now()
);

create index idx_packages_vendor on public.packages(vendor_id);
create index idx_packages_category on public.packages(category_id);
create index idx_orders_customer on public.orders(customer_id);
create index idx_orders_vendor on public.orders(vendor_id);
create index idx_orders_status on public.orders(status);
create index idx_notifications_user on public.notifications(user_id);
