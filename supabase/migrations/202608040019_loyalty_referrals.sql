create type public.referral_status as enum ('pending', 'rewarded', 'cancelled');

create table public.loyalty_accounts (
  customer_id uuid primary key references public.profiles(id) on delete cascade,
  points integer not null default 0 check (points >= 0),
  wallet_balance numeric(10,2) not null default 0 check (wallet_balance >= 0),
  referral_code text not null unique check (referral_code ~ '^[A-Z0-9]{10}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.loyalty_transactions (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.loyalty_accounts(customer_id) on delete cascade,
  kind text not null check (kind in ('order_reward', 'referral_reward', 'wallet_redemption', 'admin_adjustment')),
  description text not null check (char_length(description) between 3 and 300),
  points_delta integer not null default 0,
  amount_delta numeric(10,2) not null default 0,
  reference_id uuid,
  created_at timestamptz not null default now(),
  check (points_delta <> 0 or amount_delta <> 0)
);

create unique index idx_loyalty_transactions_idempotency
on public.loyalty_transactions(customer_id, kind, reference_id)
where reference_id is not null;
create index idx_loyalty_transactions_customer_created
on public.loyalty_transactions(customer_id, created_at desc);

create table public.customer_referrals (
  id uuid primary key default gen_random_uuid(),
  referrer_id uuid not null references public.profiles(id) on delete cascade,
  referred_id uuid not null unique references public.profiles(id) on delete cascade,
  status public.referral_status not null default 'pending',
  rewarded_at timestamptz,
  created_at timestamptz not null default now(),
  check (referrer_id <> referred_id)
);

create index idx_customer_referrals_referrer on public.customer_referrals(referrer_id, created_at desc);

alter table public.loyalty_accounts enable row level security;
alter table public.loyalty_transactions enable row level security;
alter table public.customer_referrals enable row level security;

create policy "customers_read_own_loyalty_account" on public.loyalty_accounts for select
using (customer_id = auth.uid() or public.is_admin());
create policy "customers_read_own_loyalty_transactions" on public.loyalty_transactions for select
using (customer_id = auth.uid() or public.is_admin());
create policy "customers_read_related_referrals" on public.customer_referrals for select
using (referrer_id = auth.uid() or referred_id = auth.uid() or public.is_admin());
create policy "admins_manage_loyalty_accounts" on public.loyalty_accounts for all
using (public.is_admin()) with check (public.is_admin());
create policy "admins_manage_loyalty_transactions" on public.loyalty_transactions for all
using (public.is_admin()) with check (public.is_admin());
create policy "admins_manage_referrals" on public.customer_referrals for all
using (public.is_admin()) with check (public.is_admin());

create or replace function public.create_customer_loyalty_account()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare generated_code text;
begin
  loop
    generated_code := upper(substr(encode(gen_random_bytes(8), 'hex'), 1, 10));
    begin
      insert into public.loyalty_accounts(customer_id, referral_code)
      values (new.id, generated_code);
      exit;
    exception when unique_violation then
      null;
    end;
  end loop;
  return new;
end;
$$;

create trigger profiles_create_loyalty_account
after insert on public.profiles
for each row execute function public.create_customer_loyalty_account();

insert into public.loyalty_accounts(customer_id, referral_code)
select p.id, upper(substr(md5(p.id::text), 1, 10))
from public.profiles p
on conflict (customer_id) do nothing;

create trigger loyalty_accounts_set_updated_at before update on public.loyalty_accounts
for each row execute function public.set_updated_at();

create or replace function public.apply_customer_referral(p_code text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare referrer uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select customer_id into referrer
  from public.loyalty_accounts
  where referral_code = upper(trim(p_code));
  if referrer is null then raise exception 'Referral code was not found'; end if;
  if referrer = auth.uid() then raise exception 'You cannot use your own referral code'; end if;
  if exists (select 1 from public.orders where customer_id = auth.uid() and status <> 'draft') then
    raise exception 'Referral codes are available before your first booking only';
  end if;
  insert into public.customer_referrals(referrer_id, referred_id)
  values (referrer, auth.uid());
exception
  when unique_violation then raise exception 'A referral code has already been applied';
end;
$$;

revoke all on function public.apply_customer_referral(text) from public;
grant execute on function public.apply_customer_referral(text) to authenticated;

insert into public.app_config(key, value, is_public)
values ('loyalty_settings', '{"points_per_100_rupees":1,"referral_reward_points":250}'::jsonb, true)
on conflict (key) do nothing;

create or replace function public.reward_completed_customer_order()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare settings jsonb;
declare earned_points integer;
declare referral_row public.customer_referrals%rowtype;
declare referral_points integer;
begin
  if new.status <> 'delivered' or old.status = 'delivered' then return new; end if;
  select value into settings from public.app_config where key = 'loyalty_settings';
  earned_points := floor(new.grand_total / 100) * greatest(coalesce((settings->>'points_per_100_rupees')::integer, 0), 0);
  if earned_points > 0 then
    insert into public.loyalty_transactions(customer_id, kind, description, points_delta, reference_id)
    values (new.customer_id, 'order_reward', 'Points earned for completed booking', earned_points, new.id)
    on conflict do nothing;
    if found then
      update public.loyalty_accounts set points = points + earned_points where customer_id = new.customer_id;
    end if;
  end if;

  select * into referral_row from public.customer_referrals
  where referred_id = new.customer_id and status = 'pending'
  for update;
  if found then
    referral_points := greatest(coalesce((settings->>'referral_reward_points')::integer, 0), 0);
    if referral_points > 0 then
      insert into public.loyalty_transactions(customer_id, kind, description, points_delta, reference_id)
      values (referral_row.referrer_id, 'referral_reward', 'Referral reward', referral_points, referral_row.id);
      update public.loyalty_accounts set points = points + referral_points where customer_id = referral_row.referrer_id;
    end if;
    update public.customer_referrals set status = 'rewarded', rewarded_at = now() where id = referral_row.id;
  end if;
  return new;
end;
$$;

create trigger orders_reward_completed_customer
after update of status on public.orders
for each row execute function public.reward_completed_customer_order();
