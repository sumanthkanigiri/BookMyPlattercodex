create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger vendors_set_updated_at
before update on public.vendors
for each row execute function public.set_updated_at();

create trigger packages_set_updated_at
before update on public.packages
for each row execute function public.set_updated_at();

create trigger orders_set_updated_at
before update on public.orders
for each row execute function public.set_updated_at();

create trigger payments_set_updated_at
before update on public.payments
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, role, full_name, phone, avatar_url)
  values (
    new.id,
    coalesce((new.raw_user_meta_data ->> 'role')::public.app_role, 'customer'),
    coalesce(new.raw_user_meta_data ->> 'full_name', 'BookMyPlatter Customer'),
    new.raw_user_meta_data ->> 'phone',
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.calculate_order_totals(
  package_price numeric,
  guest_count integer,
  discount numeric default 0,
  tax_rate numeric default 0.05
)
returns table (subtotal numeric, discount_total numeric, tax_total numeric, grand_total numeric)
language sql
immutable
as $$
  select
    round(package_price * guest_count, 2) as subtotal,
    round(least(greatest(discount, 0), package_price * guest_count), 2) as discount_total,
    round(greatest((package_price * guest_count) - least(greatest(discount, 0), package_price * guest_count), 0) * tax_rate, 2) as tax_total,
    round(greatest((package_price * guest_count) - least(greatest(discount, 0), package_price * guest_count), 0) * (1 + tax_rate), 2) as grand_total;
$$;

insert into public.cities (name, slug) values
  ('Hyderabad', 'hyderabad'),
  ('Bengaluru', 'bengaluru'),
  ('Chennai', 'chennai')
on conflict (slug) do nothing;

insert into public.categories (name, slug, description, sort_order) values
  ('Wedding Catering', 'wedding-catering', 'Full-service catering packages for weddings and receptions.', 1),
  ('Corporate Events', 'corporate-events', 'Breakfast, lunch, and dinner packages for office events.', 2),
  ('Birthday Parties', 'birthday-parties', 'Flexible platter packages for private celebrations.', 3)
on conflict (slug) do nothing;
