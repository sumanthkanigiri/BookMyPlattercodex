do $$ begin create type public.lead_source as enum (
  'enquiry', 'checkout_started', 'checkout_abandoned', 'whatsapp_click',
  'callback_request', 'food_tasting', 'booking_completed', 'booking_cancelled'
); exception when duplicate_object then null; end $$;

do $$ begin create type public.lead_status as enum (
  'new', 'contacted', 'qualified', 'follow_up', 'converted', 'lost'
); exception when duplicate_object then null; end $$;

do $$ begin create type public.booking_status as enum (
  'not_booked', 'checkout_started', 'booked', 'cancelled'
); exception when duplicate_object then null; end $$;

do $$ begin create type public.crm_message_status as enum (
  'queued', 'sent', 'delivered', 'failed', 'cancelled'
); exception when duplicate_object then null; end $$;

do $$ begin create type public.crm_channel as enum ('sms', 'whatsapp', 'push', 'email', 'admin'); exception when duplicate_object then null; end $$;

create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references auth.users(id) on delete set null,
  customer_name text not null default '',
  mobile text not null default '',
  email text not null default '',
  whatsapp_number text not null default '',
  event_type text not null default 'custom',
  event_date timestamptz,
  guest_count integer check (guest_count is null or guest_count > 0),
  food_preference text check (food_preference is null or food_preference in ('veg', 'non_veg', 'mixed')),
  budget numeric(12,2) check (budget is null or budget >= 0),
  event_location text not null default '',
  notes text not null default '',
  source public.lead_source not null,
  status public.lead_status not null default 'new',
  assigned_staff uuid references auth.users(id) on delete set null,
  follow_up_count integer not null default 0 check (follow_up_count >= 0),
  last_follow_up_at timestamptz,
  next_follow_up_at timestamptz,
  booking_status public.booking_status not null default 'not_booked',
  payment_status text not null default 'pending',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.lead_history (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references public.leads(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  from_status public.lead_status,
  to_status public.lead_status,
  note text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.followups (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references public.leads(id) on delete cascade,
  assigned_staff uuid references auth.users(id) on delete set null,
  channel public.crm_channel not null,
  template_key text not null,
  due_at timestamptz not null,
  completed_at timestamptz,
  status public.crm_message_status not null default 'queued',
  retry_count integer not null default 0 check (retry_count >= 0),
  last_error text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.communication_logs (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid references public.leads(id) on delete set null,
  customer_id uuid references auth.users(id) on delete set null,
  channel public.crm_channel not null,
  direction text not null default 'outbound' check (direction in ('inbound', 'outbound')),
  template_key text not null default '',
  template_id text not null default '',
  recipient text not null default '',
  subject text not null default '',
  message text not null default '',
  status public.crm_message_status not null default 'queued',
  provider_message_id text not null default '',
  error text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  sent_at timestamptz,
  delivered_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.sms_logs (
  id uuid primary key references public.communication_logs(id) on delete cascade,
  dlt_template_id text not null default '',
  fast2sms_request jsonb not null default '{}'::jsonb,
  fast2sms_response jsonb not null default '{}'::jsonb
);

create table if not exists public.whatsapp_logs (
  id uuid primary key references public.communication_logs(id) on delete cascade,
  whatsapp_template_id text not null default '',
  provider_payload jsonb not null default '{}'::jsonb,
  provider_response jsonb not null default '{}'::jsonb
);

create table if not exists public.checkout_recovery (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references public.leads(id) on delete cascade,
  customer_id uuid references auth.users(id) on delete set null,
  cart_snapshot jsonb not null default '[]'::jsonb,
  checkout_started_at timestamptz not null default now(),
  recovered_at timestamptz,
  stopped_at timestamptz,
  status public.crm_message_status not null default 'queued',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.booking_reminders (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references public.orders(id) on delete cascade,
  lead_id uuid references public.leads(id) on delete set null,
  reminder_key text not null,
  due_at timestamptz not null,
  sent_at timestamptz,
  status public.crm_message_status not null default 'queued',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.customer_activity (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references auth.users(id) on delete set null,
  lead_id uuid references public.leads(id) on delete set null,
  activity_type text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.notification_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  lead_id uuid references public.leads(id) on delete set null,
  order_id uuid references public.orders(id) on delete set null,
  title text not null,
  body text not null,
  channel public.crm_channel not null default 'push',
  status public.crm_message_status not null default 'queued',
  read_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists leads_customer_id_idx on public.leads(customer_id);
create index if not exists leads_source_idx on public.leads(source);
create index if not exists leads_status_idx on public.leads(status);
create index if not exists leads_next_follow_up_idx on public.leads(next_follow_up_at) where next_follow_up_at is not null;
create index if not exists leads_mobile_idx on public.leads(mobile) where mobile <> '';
create index if not exists followups_due_idx on public.followups(status, due_at);
create index if not exists communication_logs_lead_idx on public.communication_logs(lead_id, created_at desc);
create index if not exists checkout_recovery_due_idx on public.checkout_recovery(status, checkout_started_at) where recovered_at is null and stopped_at is null;
create index if not exists booking_reminders_due_idx on public.booking_reminders(status, due_at);
create index if not exists customer_activity_customer_idx on public.customer_activity(customer_id, created_at desc);

create or replace function public.set_crm_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_leads_updated_at on public.leads;
create trigger set_leads_updated_at before update on public.leads for each row execute function public.set_crm_updated_at();
drop trigger if exists set_followups_updated_at on public.followups;
create trigger set_followups_updated_at before update on public.followups for each row execute function public.set_crm_updated_at();
drop trigger if exists set_communication_logs_updated_at on public.communication_logs;
create trigger set_communication_logs_updated_at before update on public.communication_logs for each row execute function public.set_crm_updated_at();
drop trigger if exists set_checkout_recovery_updated_at on public.checkout_recovery;
create trigger set_checkout_recovery_updated_at before update on public.checkout_recovery for each row execute function public.set_crm_updated_at();
drop trigger if exists set_booking_reminders_updated_at on public.booking_reminders;
create trigger set_booking_reminders_updated_at before update on public.booking_reminders for each row execute function public.set_crm_updated_at();
drop trigger if exists set_notification_logs_updated_at on public.notification_logs;
create trigger set_notification_logs_updated_at before update on public.notification_logs for each row execute function public.set_crm_updated_at();

create or replace function public.is_admin_staff()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role::text in ('admin', 'support', 'operations', 'sales', 'manager')
  );
$$;

create or replace function public.record_lead_activity(
  p_source public.lead_source,
  p_customer_name text default '',
  p_mobile text default '',
  p_email text default '',
  p_whatsapp_number text default '',
  p_event_type text default 'custom',
  p_event_date timestamptz default null,
  p_guest_count integer default null,
  p_food_preference text default null,
  p_budget numeric default null,
  p_event_location text default '',
  p_notes text default '',
  p_booking_status public.booking_status default 'not_booked',
  p_payment_status text default 'pending',
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer uuid := auth.uid();
  v_lead uuid;
  v_existing uuid;
  v_next timestamptz;
begin
  select id into v_existing
  from public.leads
  where (v_customer is not null and customer_id = v_customer and status not in ('converted', 'lost'))
     or (p_mobile <> '' and mobile = p_mobile and status not in ('converted', 'lost'))
     or (p_whatsapp_number <> '' and whatsapp_number = p_whatsapp_number and status not in ('converted', 'lost'))
  order by updated_at desc
  limit 1;

  v_next := case p_source
    when 'checkout_started' then now() + interval '15 minutes'
    when 'checkout_abandoned' then now() + interval '15 minutes'
    when 'enquiry' then now() + interval '30 minutes'
    when 'whatsapp_click' then now() + interval '30 minutes'
    when 'callback_request' then now() + interval '15 minutes'
    when 'food_tasting' then now() + interval '1 hour'
    else null
  end;

  if v_existing is null then
    insert into public.leads (
      customer_id, customer_name, mobile, email, whatsapp_number, event_type,
      event_date, guest_count, food_preference, budget, event_location, notes,
      source, next_follow_up_at, booking_status, payment_status, metadata
    ) values (
      v_customer, coalesce(p_customer_name, ''), coalesce(p_mobile, ''),
      coalesce(p_email, ''), coalesce(nullif(p_whatsapp_number, ''), coalesce(p_mobile, '')),
      coalesce(p_event_type, 'custom'), p_event_date, p_guest_count,
      p_food_preference, p_budget, coalesce(p_event_location, ''),
      coalesce(p_notes, ''), p_source, v_next, p_booking_status,
      coalesce(p_payment_status, 'pending'), coalesce(p_metadata, '{}'::jsonb)
    ) returning id into v_lead;

    insert into public.lead_history(lead_id, actor_id, action, to_status, note, metadata)
    values (v_lead, v_customer, p_source::text, 'new', coalesce(p_notes, ''), coalesce(p_metadata, '{}'::jsonb));
  else
    update public.leads set
      customer_id = coalesce(customer_id, v_customer),
      customer_name = coalesce(nullif(p_customer_name, ''), customer_name),
      mobile = coalesce(nullif(p_mobile, ''), mobile),
      email = coalesce(nullif(p_email, ''), email),
      whatsapp_number = coalesce(nullif(p_whatsapp_number, ''), nullif(p_mobile, ''), whatsapp_number),
      event_type = coalesce(nullif(p_event_type, ''), event_type),
      event_date = coalesce(p_event_date, event_date),
      guest_count = coalesce(p_guest_count, guest_count),
      food_preference = coalesce(p_food_preference, food_preference),
      budget = coalesce(p_budget, budget),
      event_location = coalesce(nullif(p_event_location, ''), event_location),
      notes = trim(concat_ws(E'\n', nullif(notes, ''), nullif(p_notes, ''))),
      source = p_source,
      next_follow_up_at = coalesce(v_next, next_follow_up_at),
      booking_status = p_booking_status,
      payment_status = coalesce(nullif(p_payment_status, ''), payment_status),
      metadata = leads.metadata || coalesce(p_metadata, '{}'::jsonb)
    where id = v_existing
    returning id into v_lead;

    insert into public.lead_history(lead_id, actor_id, action, note, metadata)
    values (v_lead, v_customer, p_source::text, coalesce(p_notes, ''), coalesce(p_metadata, '{}'::jsonb));
  end if;

  insert into public.customer_activity(customer_id, lead_id, activity_type, metadata)
  values (v_customer, v_lead, p_source::text, coalesce(p_metadata, '{}'::jsonb));

  if p_source in ('checkout_started', 'checkout_abandoned') then
    insert into public.checkout_recovery(lead_id, customer_id, cart_snapshot)
    values (v_lead, v_customer, coalesce(p_metadata->'cart', '[]'::jsonb));

    insert into public.followups(lead_id, channel, template_key, due_at)
    select v_lead, item.channel::public.crm_channel, item.template_key, item.due_at
    from (values
      ('sms', 'checkout_15_min_sms', now() + interval '15 minutes'),
      ('whatsapp', 'checkout_15_min_whatsapp', now() + interval '15 minutes'),
      ('whatsapp', 'checkout_6_hour_whatsapp', now() + interval '6 hours'),
      ('sms', 'checkout_12_hour_sms', now() + interval '12 hours'),
      ('whatsapp', 'checkout_24_hour_whatsapp', now() + interval '24 hours'),
      ('whatsapp', 'checkout_3_day_final', now() + interval '3 days')
    ) as item(channel, template_key, due_at)
    where not exists (
      select 1 from public.followups f
      where f.lead_id = v_lead and f.template_key = item.template_key
    );
  elsif p_source in ('enquiry', 'whatsapp_click', 'callback_request', 'food_tasting') then
    insert into public.followups(lead_id, channel, template_key, due_at)
    select v_lead, item.channel::public.crm_channel, item.template_key, item.due_at
    from (values
      ('sms', p_source::text || '_thank_you_sms', now()),
      ('whatsapp', p_source::text || '_thank_you_whatsapp', now()),
      ('whatsapp', p_source::text || '_30_min_reminder', now() + interval '30 minutes'),
      ('whatsapp', p_source::text || '_24_hour_menu', now() + interval '24 hours'),
      ('whatsapp', p_source::text || '_3_day_reviews', now() + interval '3 days'),
      ('sms', p_source::text || '_7_day_final_offer', now() + interval '7 days')
    ) as item(channel, template_key, due_at)
    where not exists (
      select 1 from public.followups f
      where f.lead_id = v_lead and f.template_key = item.template_key
    );
  end if;

  return v_lead;
end;
$$;

create or replace function public.sync_order_to_lead()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_source public.lead_source;
  v_booking public.booking_status;
  v_lead uuid;
begin
  v_source := case when new.status in ('cancelled', 'refunded') then 'booking_cancelled'::public.lead_source else 'booking_completed'::public.lead_source end;
  v_booking := case when new.status in ('cancelled', 'refunded') then 'cancelled'::public.booking_status else 'booked'::public.booking_status end;

  select public.record_lead_activity(
    v_source,
    coalesce((select full_name from public.profiles where id = new.customer_id), ''),
    coalesce((select phone from public.profiles where id = new.customer_id), ''),
    '', '', coalesce(new.event_type, 'custom'), new.event_at, new.guest_count,
    null, new.grand_total, new.delivery_address, coalesce(new.notes, ''),
    v_booking, coalesce((select status from public.payments where order_id = new.id order by created_at desc limit 1), 'pending'),
    jsonb_build_object('order_id', new.id, 'order_status', new.status)
  ) into v_lead;

  update public.checkout_recovery set recovered_at = now(), status = 'sent'
  where lead_id = v_lead and recovered_at is null and stopped_at is null;

  if v_booking = 'booked' then
    update public.followups
    set status = 'cancelled', completed_at = now()
    where lead_id = v_lead and status = 'queued';
  end if;

  if new.event_at is not null and new.status not in ('cancelled', 'refunded') then
    insert into public.booking_reminders(order_id, lead_id, reminder_key, due_at)
    values
      (new.id, v_lead, '7_days_before', new.event_at - interval '7 days'),
      (new.id, v_lead, '3_days_before', new.event_at - interval '3 days'),
      (new.id, v_lead, '1_day_before', new.event_at - interval '1 day'),
      (new.id, v_lead, '2_hours_before', new.event_at - interval '2 hours')
    on conflict do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists sync_order_to_lead_trigger on public.orders;
create trigger sync_order_to_lead_trigger after insert or update of status on public.orders for each row execute function public.sync_order_to_lead();

alter table public.leads enable row level security;
alter table public.lead_history enable row level security;
alter table public.followups enable row level security;
alter table public.communication_logs enable row level security;
alter table public.sms_logs enable row level security;
alter table public.whatsapp_logs enable row level security;
alter table public.checkout_recovery enable row level security;
alter table public.booking_reminders enable row level security;
alter table public.customer_activity enable row level security;
alter table public.notification_logs enable row level security;

drop policy if exists "customers read own leads" on public.leads;
create policy "customers read own leads" on public.leads for select using (customer_id = auth.uid() or public.is_admin_staff());
drop policy if exists "customers create own leads" on public.leads;
create policy "customers create own leads" on public.leads for insert with check (customer_id = auth.uid() or public.is_admin_staff());
drop policy if exists "staff manage leads" on public.leads;
create policy "staff manage leads" on public.leads for all using (public.is_admin_staff()) with check (public.is_admin_staff());

drop policy if exists "lead history visibility" on public.lead_history;
create policy "lead history visibility" on public.lead_history for select using (public.is_admin_staff() or exists (select 1 from public.leads l where l.id = lead_id and l.customer_id = auth.uid()));
drop policy if exists "staff write lead history" on public.lead_history;
create policy "staff write lead history" on public.lead_history for insert with check (public.is_admin_staff() or actor_id = auth.uid());

drop policy if exists "staff manage followups" on public.followups;
create policy "staff manage followups" on public.followups for all using (public.is_admin_staff()) with check (public.is_admin_staff());
drop policy if exists "communication visibility" on public.communication_logs;
create policy "communication visibility" on public.communication_logs for select using (public.is_admin_staff() or customer_id = auth.uid());
drop policy if exists "staff manage communication" on public.communication_logs;
create policy "staff manage communication" on public.communication_logs for all using (public.is_admin_staff()) with check (public.is_admin_staff());
drop policy if exists "staff manage sms logs" on public.sms_logs;
create policy "staff manage sms logs" on public.sms_logs for all using (public.is_admin_staff()) with check (public.is_admin_staff());
drop policy if exists "staff manage whatsapp logs" on public.whatsapp_logs;
create policy "staff manage whatsapp logs" on public.whatsapp_logs for all using (public.is_admin_staff()) with check (public.is_admin_staff());

drop policy if exists "checkout recovery visibility" on public.checkout_recovery;
create policy "checkout recovery visibility" on public.checkout_recovery for select using (public.is_admin_staff() or customer_id = auth.uid());
drop policy if exists "staff manage checkout recovery" on public.checkout_recovery;
create policy "staff manage checkout recovery" on public.checkout_recovery for all using (public.is_admin_staff()) with check (public.is_admin_staff());
drop policy if exists "staff manage booking reminders" on public.booking_reminders;
create policy "staff manage booking reminders" on public.booking_reminders for all using (public.is_admin_staff()) with check (public.is_admin_staff());
drop policy if exists "activity visibility" on public.customer_activity;
create policy "activity visibility" on public.customer_activity for select using (public.is_admin_staff() or customer_id = auth.uid());
drop policy if exists "customers write activity" on public.customer_activity;
create policy "customers write activity" on public.customer_activity for insert with check (customer_id = auth.uid() or public.is_admin_staff());
drop policy if exists "notification log visibility" on public.notification_logs;
create policy "notification log visibility" on public.notification_logs for select using (public.is_admin_staff() or user_id = auth.uid());
drop policy if exists "staff manage notification logs" on public.notification_logs;
create policy "staff manage notification logs" on public.notification_logs for all using (public.is_admin_staff()) with check (public.is_admin_staff());

do $$ begin alter publication supabase_realtime add table public.leads; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.followups; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.communication_logs; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.notification_logs; exception when duplicate_object then null; end $$;

grant execute on function public.record_lead_activity(
  public.lead_source, text, text, text, text, text, timestamptz, integer,
  text, numeric, text, text, public.booking_status, text, jsonb
) to anon, authenticated;
