do $$ begin alter type public.lead_status add value if not exists 'interested'; exception when duplicate_object then null; end $$;
do $$ begin alter type public.lead_status add value if not exists 'quotation_sent'; exception when duplicate_object then null; end $$;
do $$ begin alter type public.lead_status add value if not exists 'follow_up_1'; exception when duplicate_object then null; end $$;
do $$ begin alter type public.lead_status add value if not exists 'follow_up_2'; exception when duplicate_object then null; end $$;
do $$ begin alter type public.lead_status add value if not exists 'follow_up_3'; exception when duplicate_object then null; end $$;
do $$ begin alter type public.lead_status add value if not exists 'follow_up_4'; exception when duplicate_object then null; end $$;
do $$ begin alter type public.lead_status add value if not exists 'won'; exception when duplicate_object then null; end $$;
do $$ begin alter type public.lead_status add value if not exists 'cancelled'; exception when duplicate_object then null; end $$;
do $$ begin alter type public.lead_status add value if not exists 'need_callback'; exception when duplicate_object then null; end $$;
do $$ begin alter type public.lead_status add value if not exists 'need_tasting'; exception when duplicate_object then null; end $$;
do $$ begin alter type public.lead_status add value if not exists 'need_quotation'; exception when duplicate_object then null; end $$;

alter table public.leads add column if not exists priority integer not null default 3 check (priority between 1 and 5);
alter table public.leads add column if not exists expected_revenue numeric(12,2) not null default 0 check (expected_revenue >= 0);
alter table public.leads add column if not exists probability integer not null default 10 check (probability between 0 and 100);
alter table public.leads add column if not exists lead_score integer not null default 0 check (lead_score >= 0);

alter table public.customer_activity add column if not exists anonymous_id text not null default '';
alter table public.customer_activity add column if not exists device_info jsonb not null default '{}'::jsonb;
alter table public.customer_activity add column if not exists page_path text not null default '';
alter table public.customer_activity add column if not exists package_id uuid references public.packages(id) on delete set null;
alter table public.customer_activity add column if not exists search_query text not null default '';
alter table public.customer_activity add column if not exists occurred_at timestamptz not null default now();

create index if not exists customer_activity_type_idx on public.customer_activity(activity_type, occurred_at desc);
create index if not exists customer_activity_anonymous_idx on public.customer_activity(anonymous_id, occurred_at desc) where anonymous_id <> '';
create index if not exists customer_activity_package_idx on public.customer_activity(package_id, occurred_at desc) where package_id is not null;
create index if not exists customer_activity_search_idx on public.customer_activity(search_query) where search_query <> '';
create index if not exists leads_score_idx on public.leads(lead_score desc, updated_at desc);

create or replace function public.record_customer_activity(
  p_activity_type text,
  p_anonymous_id text default '',
  p_page_path text default '',
  p_package_id uuid default null,
  p_search_query text default '',
  p_device_info jsonb default '{}'::jsonb,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer uuid := auth.uid();
  v_activity uuid;
  v_lead uuid;
  v_score_delta integer := case p_activity_type
    when 'booking_completed' then 60
    when 'checkout_started' then 25
    when 'quote_request' then 30
    when 'food_tasting' then 30
    when 'whatsapp_click' then 20
    when 'call_click' then 20
    when 'cart_added' then 15
    when 'favourite' then 10
    when 'package_viewed' then 8
    when 'search' then 5
    else 2
  end;
begin
  select id into v_lead
  from public.leads
  where (v_customer is not null and customer_id = v_customer)
     or (coalesce(p_anonymous_id, '') <> '' and metadata->>'anonymous_id' = p_anonymous_id)
  order by updated_at desc
  limit 1;

  insert into public.customer_activity(
    customer_id, lead_id, activity_type, anonymous_id, device_info,
    page_path, package_id, search_query, metadata, occurred_at
  ) values (
    v_customer, v_lead, p_activity_type, coalesce(p_anonymous_id, ''),
    coalesce(p_device_info, '{}'::jsonb), coalesce(p_page_path, ''),
    p_package_id, coalesce(p_search_query, ''), coalesce(p_metadata, '{}'::jsonb), now()
  ) returning id into v_activity;

  if v_lead is not null then
    update public.leads
    set lead_score = greatest(0, lead_score + v_score_delta),
        metadata = metadata || jsonb_build_object('last_activity', p_activity_type)
    where id = v_lead;

    insert into public.lead_history(lead_id, actor_id, action, note, metadata)
    values (v_lead, v_customer, p_activity_type, 'Customer activity tracked', coalesce(p_metadata, '{}'::jsonb));
  end if;

  return v_activity;
end;
$$;

grant execute on function public.record_customer_activity(text, text, text, uuid, text, jsonb, jsonb) to anon, authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1
       from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'customer_activity'
     ) then
    alter publication supabase_realtime add table public.customer_activity;
  end if;
end;
$$;
