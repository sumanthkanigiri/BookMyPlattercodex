-- Single-brand operations management. All mutation policies are restricted to
-- BookMyPlatter staff; customers retain access only to their own delivery state.
alter type public.app_role add value if not exists 'kitchen';

create or replace function public.is_operations_staff()
returns boolean language sql stable security definer set search_path = public
as $$ select coalesce((select role::text in ('admin','support','kitchen','delivery_partner') from public.profiles where id = auth.uid()), false) $$;

create table public.staff_members (
  id uuid primary key references public.profiles(id) on delete cascade,
  employee_code text not null unique,
  department text not null check (department in ('kitchen','delivery','operations','support','finance')),
  job_title text not null check (char_length(job_title) between 2 and 80),
  phone text not null,
  is_active boolean not null default true,
  joined_on date not null default current_date,
  created_at timestamptz not null default now()
);

create table public.staff_shifts (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.staff_members(id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null check (ends_at > starts_at),
  notes text check (char_length(notes) <= 500),
  created_by uuid not null default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.staff_attendance (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.staff_members(id) on delete cascade,
  shift_date date not null default current_date,
  checked_in_at timestamptz,
  checked_out_at timestamptz check (checked_out_at is null or checked_out_at >= checked_in_at),
  status text not null check (status in ('present','absent','leave')),
  unique(staff_id, shift_date)
);

create table public.suppliers (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 120),
  phone text not null,
  email text,
  address text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  unit text not null check (unit in ('kg','g','l','ml','piece','pack')),
  quantity numeric(12,3) not null default 0 check (quantity >= 0),
  reorder_level numeric(12,3) not null default 0 check (reorder_level >= 0),
  unit_cost numeric(12,2) not null default 0 check (unit_cost >= 0),
  updated_at timestamptz not null default now()
);

create table public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.inventory_items(id),
  movement_type text not null check (movement_type in ('stock_in','stock_out','adjustment')),
  quantity numeric(12,3) not null check (quantity > 0),
  unit_cost numeric(12,2) check (unit_cost >= 0),
  reference text check (char_length(reference) <= 120),
  created_by uuid not null default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.purchase_entries (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references public.suppliers(id),
  invoice_number text not null,
  purchased_at date not null default current_date,
  total numeric(12,2) not null check (total >= 0),
  notes text,
  created_by uuid not null default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now(),
  unique(supplier_id, invoice_number)
);

create table public.order_operations (
  order_id uuid primary key references public.orders(id) on delete cascade,
  kitchen_notes text check (char_length(kitchen_notes) <= 2000),
  assigned_kitchen_staff uuid references public.staff_members(id),
  preparation_started_at timestamptz,
  ready_at timestamptz,
  updated_by uuid references public.profiles(id),
  updated_at timestamptz not null default now()
);

create table public.delivery_assignments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete cascade,
  delivery_person_id uuid not null references public.staff_members(id),
  status text not null default 'assigned' check (status in ('assigned','picked_up','en_route','arrived','verified','completed','cancelled')),
  current_latitude numeric(9,6) check (current_latitude between -90 and 90),
  current_longitude numeric(9,6) check (current_longitude between -180 and 180),
  estimated_arrival_at timestamptz,
  otp_digest text not null,
  otp_verified_at timestamptz,
  delivered_at timestamptz,
  assigned_by uuid not null default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.business_expenses (
  id uuid primary key default gen_random_uuid(),
  category text not null check (char_length(category) between 2 and 60),
  description text not null check (char_length(description) between 2 and 300),
  amount numeric(12,2) not null check (amount > 0),
  expense_date date not null default current_date,
  gst_amount numeric(12,2) not null default 0 check (gst_amount >= 0),
  created_by uuid not null default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now()
);

create index staff_shifts_time_idx on public.staff_shifts(starts_at, ends_at);
create index attendance_date_idx on public.staff_attendance(shift_date, staff_id);
create index inventory_low_stock_idx on public.inventory_items(quantity, reorder_level);
create index stock_movements_item_time_idx on public.stock_movements(item_id, created_at desc);
create index delivery_status_eta_idx on public.delivery_assignments(status, estimated_arrival_at);
create index expenses_date_idx on public.business_expenses(expense_date);

alter table public.staff_members enable row level security;
alter table public.staff_shifts enable row level security;
alter table public.staff_attendance enable row level security;
alter table public.suppliers enable row level security;
alter table public.inventory_items enable row level security;
alter table public.stock_movements enable row level security;
alter table public.purchase_entries enable row level security;
alter table public.order_operations enable row level security;
alter table public.delivery_assignments enable row level security;
alter table public.business_expenses enable row level security;

create policy staff_read_operations on public.staff_members for select using (public.is_operations_staff());
create policy admin_manage_staff on public.staff_members for all using (public.current_role() = 'admin') with check (public.current_role() = 'admin');
create policy staff_read_shifts on public.staff_shifts for select using (public.is_operations_staff());
create policy admin_manage_shifts on public.staff_shifts for all using (public.current_role() = 'admin') with check (public.current_role() = 'admin');
create policy staff_read_attendance on public.staff_attendance for select using (public.is_operations_staff());
create policy admin_manage_attendance on public.staff_attendance for all using (public.current_role() = 'admin') with check (public.current_role() = 'admin');
create policy operations_manage_suppliers on public.suppliers for all using (public.is_operations_staff()) with check (public.is_operations_staff());
create policy operations_manage_inventory on public.inventory_items for all using (public.is_operations_staff()) with check (public.is_operations_staff());
create policy operations_manage_stock on public.stock_movements for all using (public.is_operations_staff()) with check (public.is_operations_staff());
create policy operations_manage_purchases on public.purchase_entries for all using (public.is_operations_staff()) with check (public.is_operations_staff());
create policy operations_manage_kitchen on public.order_operations for all using (public.is_operations_staff()) with check (public.is_operations_staff());
create policy operations_read_deliveries on public.delivery_assignments for select using (public.is_operations_staff());
create policy managers_create_deliveries on public.delivery_assignments for insert with check (public.current_role() in ('admin','support'));
create policy managers_or_assignee_update_deliveries on public.delivery_assignments for update
using (public.current_role() in ('admin','support') or delivery_person_id=auth.uid())
with check (public.current_role() in ('admin','support') or delivery_person_id=auth.uid());
create policy finance_read_expenses on public.business_expenses for select using (public.current_role() in ('admin','support'));
create policy admin_manage_expenses on public.business_expenses for all using (public.current_role() = 'admin') with check (public.current_role() = 'admin');

create or replace function public.record_stock_movement(
  p_item_id uuid, p_type text, p_quantity numeric, p_unit_cost numeric default null, p_reference text default null
) returns public.inventory_items language plpgsql security definer set search_path = public as $$
declare item public.inventory_items; delta numeric;
begin
  if not public.is_operations_staff() then raise exception 'Forbidden'; end if;
  if p_type not in ('stock_in','stock_out','adjustment') or p_quantity <= 0 then raise exception 'Invalid stock movement'; end if;
  select * into item from public.inventory_items where id = p_item_id for update;
  if not found then raise exception 'Inventory item not found'; end if;
  delta := case when p_type = 'stock_out' then -p_quantity else p_quantity end;
  if item.quantity + delta < 0 then raise exception 'Insufficient stock'; end if;
  update public.inventory_items set quantity = quantity + delta, unit_cost = coalesce(p_unit_cost, unit_cost), updated_at = now() where id = p_item_id returning * into item;
  insert into public.stock_movements(item_id,movement_type,quantity,unit_cost,reference) values(p_item_id,p_type,p_quantity,p_unit_cost,nullif(trim(p_reference),''));
  return item;
end $$;

create or replace function public.assign_delivery(p_order_id uuid, p_staff_id uuid, p_eta timestamptz)
returns text language plpgsql security definer set search_path = public as $$
declare raw_otp text; assignment_id uuid;
begin
  if public.current_role() not in ('admin','support') then raise exception 'Forbidden'; end if;
  if not exists(select 1 from public.staff_members where id=p_staff_id and department='delivery' and is_active) then raise exception 'Active delivery staff required'; end if;
  raw_otp := lpad(floor(random()*1000000)::text, 6, '0');
  insert into public.delivery_assignments(order_id,delivery_person_id,estimated_arrival_at,otp_digest)
  values(p_order_id,p_staff_id,p_eta,crypt(raw_otp,gen_salt('bf')))
  on conflict(order_id) do update set delivery_person_id=excluded.delivery_person_id, estimated_arrival_at=excluded.estimated_arrival_at, otp_digest=excluded.otp_digest, status='assigned', updated_at=now()
  returning id into assignment_id;
  insert into public.admin_audit_logs(actor_id,action,entity_type,entity_id,new_data) values(auth.uid(),'delivery_assigned','delivery_assignment',assignment_id,jsonb_build_object('order_id',p_order_id,'staff_id',p_staff_id));
  return raw_otp;
end $$;

create or replace function public.verify_delivery_otp(p_order_id uuid, p_otp text)
returns boolean language plpgsql security definer set search_path = public as $$
declare assignment public.delivery_assignments;
begin
  select * into assignment from public.delivery_assignments where order_id=p_order_id for update;
  if not found then return false; end if;
  if public.current_role() not in ('admin','support') and assignment.delivery_person_id <> auth.uid() then raise exception 'Forbidden'; end if;
  if assignment.otp_verified_at is not null then return false; end if;
  if crypt(p_otp, assignment.otp_digest) <> assignment.otp_digest then return false; end if;
  update public.delivery_assignments set otp_verified_at=now(), delivered_at=now(), status='completed', updated_at=now() where id=assignment.id;
  return true;
end $$;

create or replace function public.update_delivery_location(p_order_id uuid, p_latitude numeric, p_longitude numeric, p_eta timestamptz default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_latitude not between -90 and 90 or p_longitude not between -180 and 180 then raise exception 'Invalid coordinates'; end if;
  update public.delivery_assignments
  set current_latitude=p_latitude, current_longitude=p_longitude, estimated_arrival_at=coalesce(p_eta,estimated_arrival_at), status=case when status in ('assigned','picked_up') then 'en_route' else status end, updated_at=now()
  where order_id=p_order_id and (delivery_person_id=auth.uid() or public.current_role() in ('admin','support'));
  if not found then raise exception 'Delivery assignment not found or forbidden'; end if;
end $$;

grant execute on function public.record_stock_movement(uuid,text,numeric,numeric,text) to authenticated;
grant execute on function public.assign_delivery(uuid,uuid,timestamptz) to authenticated;
grant execute on function public.verify_delivery_otp(uuid,text) to authenticated;
grant execute on function public.update_delivery_location(uuid,numeric,numeric,timestamptz) to authenticated;

create or replace function public.customer_delivery_tracking(p_order_id uuid)
returns table(status text, current_latitude numeric, current_longitude numeric, estimated_arrival_at timestamptz, delivered_at timestamptz)
language sql stable security definer set search_path = public as $$
  select d.status, d.current_latitude, d.current_longitude, d.estimated_arrival_at, d.delivered_at
  from public.delivery_assignments d join public.orders o on o.id=d.order_id
  where d.order_id=p_order_id and o.customer_id=auth.uid()
$$;
grant execute on function public.customer_delivery_tracking(uuid) to authenticated;

do $$ begin
  alter publication supabase_realtime add table public.order_operations;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.delivery_assignments;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.inventory_items;
exception when duplicate_object then null; end $$;
