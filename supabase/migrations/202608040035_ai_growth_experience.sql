-- Company-owned AI growth and customer experience layer for BookMyPlatter.
-- This migration does not create vendor registration, vendor marketplace, or vendor app workflows.

create table if not exists public.ai_assistant_threads (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references public.profiles(id) on delete set null,
  anonymous_session_id text not null default '',
  channel text not null check (channel in ('flutter_app', 'website', 'admin')),
  intent text not null default 'catering_planning',
  event_type text not null default '',
  guest_count integer check (guest_count is null or guest_count > 0),
  budget numeric(12,2) check (budget is null or budget >= 0),
  food_preference text check (food_preference is null or food_preference in ('veg', 'non_veg', 'both', 'mixed')),
  source text not null default 'ai_assistant',
  device jsonb not null default '{}'::jsonb,
  lead_id uuid references public.leads(id) on delete set null,
  status text not null default 'active' check (status in ('active', 'converted', 'closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_assistant_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.ai_assistant_threads(id) on delete cascade,
  customer_id uuid references public.profiles(id) on delete set null,
  role text not null check (role in ('customer', 'assistant', 'staff')),
  message text not null,
  recommendations jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.ai_catering_recommendations (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references public.profiles(id) on delete set null,
  thread_id uuid references public.ai_assistant_threads(id) on delete cascade,
  package_id uuid references public.packages(id) on delete set null,
  recommendation_type text not null check (recommendation_type in ('best_package', 'budget_plan', 'guest_estimate', 'menu', 'dish', 'festival', 'seasonal', 'offer', 'reorder')),
  score numeric(8,3) not null default 0,
  reason text not null,
  metadata jsonb not null default '{}'::jsonb,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.ai_content_jobs (
  id uuid primary key default gen_random_uuid(),
  content_type text not null check (content_type in ('seo_blog', 'faq', 'schema', 'image_alt_tags', 'internal_links', 'meta_tags')),
  status public.automation_job_status not null default 'scheduled',
  title text not null,
  category text not null default 'Catering Guides',
  author_id uuid references public.profiles(id) on delete set null,
  target_slug text not null default '',
  seo_keywords text[] not null default '{}'::text[],
  meta_description text not null default '',
  generated_payload jsonb not null default '{}'::jsonb,
  website_blog_post_id uuid references public.website_blog_posts(id) on delete set null,
  scheduled_publish_at timestamptz,
  published_at timestamptz,
  last_error text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_marketing_campaign_drafts (
  id uuid primary key default gen_random_uuid(),
  campaign_type text not null check (campaign_type in ('instagram', 'facebook', 'google_business', 'whatsapp', 'sms', 'push', 'festival', 'referral', 'discount')),
  status public.automation_job_status not null default 'scheduled',
  audience text not null default 'customers',
  title text not null,
  message text not null,
  cta_label text not null default '',
  cta_url text not null default '',
  scheduled_at timestamptz,
  published_at timestamptz,
  generated_payload jsonb not null default '{}'::jsonb,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.personalized_customer_offers (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  package_id uuid references public.packages(id) on delete set null,
  title text not null,
  description text not null,
  offer_code text not null default '',
  discount_type text not null default 'flat' check (discount_type in ('flat', 'percentage', 'wallet_points')),
  discount_value numeric(12,2) not null default 0 check (discount_value >= 0),
  reason text not null default '',
  starts_at timestamptz not null default now(),
  expires_at timestamptz not null,
  is_redeemed boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.review_moderation_queue (
  id uuid primary key default gen_random_uuid(),
  review_id uuid references public.reviews(id) on delete cascade,
  website_review_id uuid references public.website_reviews(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'needs_reply')),
  moderation_notes text not null default '',
  reply_text text not null default '',
  photo_urls text[] not null default '{}'::text[],
  video_urls text[] not null default '{}'::text[],
  verified_order_id uuid references public.orders(id) on delete set null,
  assigned_to uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (review_id is not null or website_review_id is not null)
);

create or replace function public.generate_ai_catering_plan(
  p_event_type text,
  p_food_preference text,
  p_guest_count integer,
  p_budget_max numeric
)
returns jsonb
language plpgsql
stable
security invoker
as $$
declare
  v_package jsonb;
  v_budget_per_guest numeric;
  v_servings jsonb;
  v_faq jsonb;
begin
  select jsonb_build_object(
    'id', p.id,
    'name', p.name,
    'price_per_guest', p.price_per_guest,
    'rating', p.rating,
    'package_type', p.package_type,
    'cuisine', p.cuisine,
    'reason', concat('Best fit for ', coalesce(p_event_type, 'your event'), ' with ', coalesce(p_food_preference, 'mixed'), ' preference and ', p_guest_count, ' guests.')
  ) into v_package
  from public.recommend_catering_packages(p_event_type, p_food_preference, p_guest_count, p_budget_max) r
  join public.packages p on p.id = r.package_id
  order by r.recommendation_score desc
  limit 1;

  v_budget_per_guest := case when p_guest_count > 0 and p_budget_max is not null then round(p_budget_max / p_guest_count, 2) else null end;
  v_servings := jsonb_build_object(
    'starters', greatest(2, ceil(p_guest_count / 25.0)::int),
    'mains', greatest(3, ceil(p_guest_count / 35.0)::int),
    'desserts', greatest(1, ceil(p_guest_count / 50.0)::int),
    'service_staff', greatest(1, ceil(p_guest_count / 40.0)::int),
    'buffer_percent', case when p_guest_count >= 200 then 8 else 10 end
  );
  v_faq := jsonb_build_array(
    jsonb_build_object('question', 'How early should I book?', 'answer', 'Book at least 7 days ahead for standard catering and 15 days ahead for weddings or festival events.'),
    jsonb_build_object('question', 'Can I customize the menu?', 'answer', 'Yes. You can customize dishes, live counters, beverages, desserts, and add-ons before checkout.'),
    jsonb_build_object('question', 'Do you support food tasting?', 'answer', 'Yes. Food tasting can be requested from the app, website, or admin CRM.')
  );

  return jsonb_build_object(
    'best_package', coalesce(v_package, '{}'::jsonb),
    'budget', jsonb_build_object('maximum', p_budget_max, 'per_guest', v_budget_per_guest, 'guest_count', p_guest_count),
    'guest_estimate', jsonb_build_object('entered_guests', p_guest_count, 'recommended_buffer_guests', ceil(p_guest_count * 1.08)::int),
    'serving_plan', v_servings,
    'festival_recommendation', case when extract(month from now()) in (8,9,10,11,12) then 'Add festival sweets, live chaat, and premium beverage counters.' else 'Add seasonal fruits, welcome drinks, and a signature dessert counter.' end,
    'support_answer', 'BookMyPlatter specialists can confirm menu, pricing, tasting, and delivery details instantly from this plan.',
    'faq', v_faq
  );
end;
$$;

create index if not exists ai_assistant_threads_customer_idx on public.ai_assistant_threads(customer_id, created_at desc);
create index if not exists ai_assistant_messages_thread_idx on public.ai_assistant_messages(thread_id, created_at);
create index if not exists ai_catering_recommendations_customer_idx on public.ai_catering_recommendations(customer_id, created_at desc);
create index if not exists ai_content_jobs_status_idx on public.ai_content_jobs(status, scheduled_publish_at);
create index if not exists ai_marketing_campaign_drafts_status_idx on public.ai_marketing_campaign_drafts(status, scheduled_at);
create index if not exists personalized_customer_offers_customer_idx on public.personalized_customer_offers(customer_id, expires_at desc);
create index if not exists review_moderation_queue_status_idx on public.review_moderation_queue(status, created_at desc);

alter table public.ai_assistant_threads enable row level security;
alter table public.ai_assistant_messages enable row level security;
alter table public.ai_catering_recommendations enable row level security;
alter table public.ai_content_jobs enable row level security;
alter table public.ai_marketing_campaign_drafts enable row level security;
alter table public.personalized_customer_offers enable row level security;
alter table public.review_moderation_queue enable row level security;

create policy "customers read own ai assistant threads" on public.ai_assistant_threads for select using (customer_id = auth.uid());
create policy "customers create own ai assistant threads" on public.ai_assistant_threads for insert with check (customer_id = auth.uid());
create policy "anonymous create ai assistant threads" on public.ai_assistant_threads for insert with check (customer_id is null and anonymous_session_id <> '');
create policy "staff manage ai assistant threads" on public.ai_assistant_threads for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "customers read own ai assistant messages" on public.ai_assistant_messages for select using (customer_id = auth.uid() or exists (select 1 from public.ai_assistant_threads t where t.id = thread_id and t.customer_id = auth.uid()));
create policy "customers insert own ai assistant messages" on public.ai_assistant_messages for insert with check (customer_id = auth.uid() or exists (select 1 from public.ai_assistant_threads t where t.id = thread_id and t.customer_id = auth.uid()));
create policy "staff manage ai assistant messages" on public.ai_assistant_messages for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "customers read own ai recommendations" on public.ai_catering_recommendations for select using (customer_id = auth.uid());
create policy "staff manage ai recommendations" on public.ai_catering_recommendations for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "staff manage ai content jobs" on public.ai_content_jobs for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "staff manage ai marketing drafts" on public.ai_marketing_campaign_drafts for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "customers read own personalized offers" on public.personalized_customer_offers for select using (customer_id = auth.uid() and starts_at <= now() and expires_at >= now());
create policy "staff manage personalized offers" on public.personalized_customer_offers for all using (public.is_admin_staff()) with check (public.is_admin_staff());
create policy "staff manage review moderation" on public.review_moderation_queue for all using (public.is_admin_staff()) with check (public.is_admin_staff());

create trigger ai_assistant_threads_set_updated_at before update on public.ai_assistant_threads for each row execute function public.set_updated_at();
create trigger ai_content_jobs_set_updated_at before update on public.ai_content_jobs for each row execute function public.set_updated_at();
create trigger ai_marketing_campaign_drafts_set_updated_at before update on public.ai_marketing_campaign_drafts for each row execute function public.set_updated_at();
create trigger review_moderation_queue_set_updated_at before update on public.review_moderation_queue for each row execute function public.set_updated_at();

grant execute on function public.generate_ai_catering_plan(text, text, integer, numeric) to anon, authenticated;

do $$
declare
  table_name text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach table_name in array array['ai_assistant_threads', 'ai_assistant_messages', 'ai_catering_recommendations', 'ai_content_jobs', 'ai_marketing_campaign_drafts', 'personalized_customer_offers', 'review_moderation_queue'] loop
      if not exists (
        select 1 from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = table_name
      ) then
        execute format('alter publication supabase_realtime add table public.%I', table_name);
      end if;
    end loop;
  end if;
end;
$$;
