create or replace function public.enforce_single_default_address()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.is_default then
    update public.customer_addresses
    set is_default = false
    where customer_id = new.customer_id and id is distinct from new.id and is_default;
  end if;
  return new;
end;
$$;

create trigger customer_addresses_single_default
before insert or update of is_default on public.customer_addresses
for each row execute function public.enforce_single_default_address();

with ranked_defaults as (
  select id, row_number() over (partition by customer_id order by updated_at desc, created_at desc) as position
  from public.customer_addresses where is_default
)
update public.customer_addresses a set is_default = false
from ranked_defaults r where a.id = r.id and r.position > 1;

create unique index idx_customer_addresses_one_default
on public.customer_addresses(customer_id)
where is_default;
