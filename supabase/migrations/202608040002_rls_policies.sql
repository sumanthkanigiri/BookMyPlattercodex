alter table public.profiles enable row level security;
alter table public.cities enable row level security;
alter table public.areas enable row level security;
alter table public.vendors enable row level security;
alter table public.categories enable row level security;
alter table public.packages enable row level security;
alter table public.menu_items enable row level security;
alter table public.coupons enable row level security;
alter table public.orders enable row level security;
alter table public.payments enable row level security;
alter table public.notifications enable row level security;
alter table public.reviews enable row level security;

create or replace function public.current_role()
returns public.app_role
language sql
stable
as $$ select role from public.profiles where id = auth.uid() $$;

create or replace function public.is_admin()
returns boolean
language sql
stable
as $$ select public.current_role() in ('admin', 'support') $$;

create policy "profiles_read_own_or_admin" on public.profiles for select using (id = auth.uid() or public.is_admin());
create policy "profiles_update_own" on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());

create policy "public_read_active_cities" on public.cities for select using (is_active or public.is_admin());
create policy "public_read_active_areas" on public.areas for select using (is_active or public.is_admin());
create policy "public_read_active_categories" on public.categories for select using (is_active or public.is_admin());
create policy "public_read_active_vendors" on public.vendors for select using (is_active or public.is_admin());
create policy "public_read_active_packages" on public.packages for select using (is_active or public.is_admin());
create policy "public_read_package_menu" on public.menu_items for select using (exists (select 1 from public.packages p where p.id = package_id and p.is_active));

create policy "admin_manage_cities" on public.cities for all using (public.is_admin()) with check (public.is_admin());
create policy "admin_manage_areas" on public.areas for all using (public.is_admin()) with check (public.is_admin());
create policy "admin_manage_categories" on public.categories for all using (public.is_admin()) with check (public.is_admin());
create policy "admin_manage_coupons" on public.coupons for all using (public.is_admin()) with check (public.is_admin());

create policy "vendors_manage_own_vendor" on public.vendors for update using (owner_id = auth.uid() or public.is_admin()) with check (owner_id = auth.uid() or public.is_admin());
create policy "vendors_manage_own_packages" on public.packages for all using (exists (select 1 from public.vendors v where v.id = vendor_id and v.owner_id = auth.uid()) or public.is_admin()) with check (exists (select 1 from public.vendors v where v.id = vendor_id and v.owner_id = auth.uid()) or public.is_admin());
create policy "vendors_manage_own_menu" on public.menu_items for all using (exists (select 1 from public.packages p join public.vendors v on v.id = p.vendor_id where p.id = package_id and v.owner_id = auth.uid()) or public.is_admin()) with check (exists (select 1 from public.packages p join public.vendors v on v.id = p.vendor_id where p.id = package_id and v.owner_id = auth.uid()) or public.is_admin());

create policy "customers_create_orders" on public.orders for insert with check (customer_id = auth.uid());
create policy "order_participants_read" on public.orders for select using (customer_id = auth.uid() or exists (select 1 from public.vendors v where v.id = vendor_id and v.owner_id = auth.uid()) or public.is_admin());
create policy "admins_update_orders" on public.orders for update using (public.is_admin() or exists (select 1 from public.vendors v where v.id = vendor_id and v.owner_id = auth.uid())) with check (public.is_admin() or exists (select 1 from public.vendors v where v.id = vendor_id and v.owner_id = auth.uid()));

create policy "payments_order_participants_read" on public.payments for select using (exists (select 1 from public.orders o where o.id = order_id and (o.customer_id = auth.uid() or public.is_admin())));
create policy "notifications_read_own" on public.notifications for select using (user_id = auth.uid() or public.is_admin());
create policy "notifications_update_own" on public.notifications for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "reviews_public_read" on public.reviews for select using (true);
create policy "customers_create_review" on public.reviews for insert with check (customer_id = auth.uid());
