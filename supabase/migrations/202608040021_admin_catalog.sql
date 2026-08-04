alter table public.banners
  add column banner_type text not null default 'home'
    check (banner_type in ('home', 'festival', 'promotion', 'popup')),
  add column updated_at timestamptz not null default now();

alter table public.packages drop constraint if exists packages_type_check;
alter table public.packages add constraint packages_type_check
check (package_type in ('veg', 'non_veg', 'platter_box', 'catering_combo'));

create table public.package_images (
  id uuid primary key default gen_random_uuid(),
  package_id uuid not null references public.packages(id) on delete cascade,
  image_url text not null,
  storage_path text not null unique,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create index idx_package_images_package_sort on public.package_images(package_id, sort_order);
alter table public.package_images enable row level security;
create policy "public_read_package_images_metadata" on public.package_images for select
using (exists (select 1 from public.packages p where p.id = package_id and (p.is_active or public.is_admin())));
create policy "admins_manage_package_images_metadata" on public.package_images for all
using (public.is_admin()) with check (public.is_admin());

create trigger banners_set_updated_at before update on public.banners
for each row execute function public.set_updated_at();

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('banner-images', 'banner-images', true, 10485760, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "public_read_banner_images" on storage.objects for select
using (bucket_id = 'banner-images');

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'packages'
  ) then alter publication supabase_realtime add table public.packages; end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'banners'
  ) then alter publication supabase_realtime add table public.banners; end if;
end;
$$;

drop policy if exists "admin_manage_categories" on public.categories;
drop policy if exists "admin_manage_coupons" on public.coupons;
drop policy if exists "admin_manage_banners" on public.banners;
drop policy if exists "vendors_manage_own_packages" on public.packages;
drop policy if exists "admins_manage_package_images_metadata" on public.package_images;
drop policy if exists "admins_manage_storage" on storage.objects;

create policy "administrators_manage_categories" on public.categories for all
using (public.current_role() = 'admin') with check (public.current_role() = 'admin');
create policy "administrators_manage_coupons" on public.coupons for all
using (public.current_role() = 'admin') with check (public.current_role() = 'admin');
create policy "administrators_manage_banners" on public.banners for all
using (public.current_role() = 'admin') with check (public.current_role() = 'admin');
create policy "administrators_manage_packages" on public.packages for all
using (public.current_role() = 'admin') with check (public.current_role() = 'admin');
create policy "administrators_manage_package_images" on public.package_images for all
using (public.current_role() = 'admin') with check (public.current_role() = 'admin');
create policy "administrators_manage_storage" on storage.objects for all to authenticated
using (public.current_role() = 'admin') with check (public.current_role() = 'admin');
