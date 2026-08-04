create table if not exists public.marketplace_content_items (
  id uuid primary key default gen_random_uuid(),
  collection_key text not null,
  title text not null,
  subtitle text,
  icon text,
  route text,
  search_query text,
  image_url text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint marketplace_content_items_collection_key_check
    check (collection_key ~ '^[a-z0-9_]+$'),
  constraint marketplace_content_items_route_or_query_check
    check (route is null or route like '/%')
);

create index if not exists idx_marketplace_content_items_active
on public.marketplace_content_items(collection_key, is_active, sort_order)
where is_active;

alter table public.marketplace_content_items enable row level security;

drop policy if exists "public_read_active_marketplace_content" on public.marketplace_content_items;
create policy "public_read_active_marketplace_content"
on public.marketplace_content_items for select
using (
  is_active
  and (starts_at is null or starts_at <= now())
  and (ends_at is null or ends_at > now())
);

drop policy if exists "admin_manage_marketplace_content" on public.marketplace_content_items;
create policy "admin_manage_marketplace_content"
on public.marketplace_content_items for all
using (public.is_admin())
with check (public.is_admin());

drop trigger if exists marketplace_content_items_set_updated_at on public.marketplace_content_items;
create trigger marketplace_content_items_set_updated_at
before update on public.marketplace_content_items
for each row execute function public.set_updated_at();
