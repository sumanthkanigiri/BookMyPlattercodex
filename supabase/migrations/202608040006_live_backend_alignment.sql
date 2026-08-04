alter table public.categories add column if not exists icon text not null default '🍽️';

create or replace function public.search_packages(search_text text default '')
returns table (
  id uuid,
  category_id uuid,
  name text,
  description text,
  price_per_guest numeric,
  min_guests integer,
  rating numeric,
  is_veg boolean
)
language sql
stable
as $$
  select p.id, p.category_id, p.name, p.description, p.price_per_guest, p.min_guests, p.rating, p.is_veg
  from public.packages p
  where p.is_active
    and (search_text = '' or p.name ilike '%' || search_text || '%' or p.description ilike '%' || search_text || '%')
  order by p.rating desc, p.created_at desc;
$$;

update public.categories set icon = '💍' where slug = 'wedding-catering';
update public.categories set icon = '🏢' where slug = 'corporate-events';
update public.categories set icon = '🎂' where slug = 'birthday-parties';
