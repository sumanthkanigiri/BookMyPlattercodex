create table public.booking_drafts (
  customer_id uuid primary key references public.profiles(id) on delete cascade,
  answers jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.booking_drafts enable row level security;
create policy "customers_manage_own_booking_draft"
on public.booking_drafts for all
using (customer_id = auth.uid())
with check (customer_id = auth.uid());

create trigger booking_drafts_set_updated_at
before update on public.booking_drafts
for each row execute function public.set_updated_at();

create or replace function public.recommend_catering_packages(
  p_event_type text,
  p_food_preference text,
  p_guest_count integer,
  p_budget_max numeric
)
returns table(package_id uuid, recommendation_score numeric)
language sql
stable
security invoker
as $$
  select
    p.id,
    (
      case when p.event_types @> array[p_event_type] then 35 else 0 end +
      case
        when p_food_preference = 'both' then 15
        when p_food_preference = 'veg' and p.is_veg then 15
        when p_food_preference = 'non_veg' and not p.is_veg then 15
        else 0
      end +
      case
        when p_guest_count < 50 and p.package_type = 'platter_box' then 25
        when p_guest_count >= 50 and p.package_type <> 'platter_box' then 25
        else 0
      end +
      least(p.rating * 3, 15) +
      least(p.popularity_score::numeric / 100, 10)
    )::numeric as recommendation_score
  from public.packages p
  where p.is_active
    and p_guest_count between p.min_guests and p.max_guests
    and (p_budget_max is null or p.price_per_guest * p_guest_count <= p_budget_max)
    and (
      p_food_preference = 'both'
      or (p_food_preference = 'veg' and p.is_veg)
      or (p_food_preference = 'non_veg' and not p.is_veg)
    )
  order by recommendation_score desc, p.rating desc, p.popularity_score desc
  limit 20;
$$;

grant execute on function public.recommend_catering_packages(text, text, integer, numeric)
to anon, authenticated;
