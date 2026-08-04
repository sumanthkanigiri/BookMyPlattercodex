create table if not exists public.website_blog_posts (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  excerpt text not null default '',
  content text not null,
  category text not null default 'Catering Guides',
  tags text[] not null default '{}'::text[],
  cover_image_url text,
  meta_title text,
  meta_description text,
  schema_json jsonb not null default '{}'::jsonb,
  canonical_url text,
  published_at timestamptz,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.website_faqs (
  id uuid primary key default gen_random_uuid(),
  question text not null,
  answer text not null,
  category text not null default 'General',
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.website_reviews (
  id uuid primary key default gen_random_uuid(),
  customer_name text not null,
  rating numeric(2,1) not null check (rating between 1 and 5),
  review_text text not null,
  source text not null default 'Google',
  city text not null default '',
  published_at timestamptz not null default now(),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists website_blog_posts_published_idx on public.website_blog_posts(is_published, published_at desc);
create index if not exists website_blog_posts_tags_idx on public.website_blog_posts using gin(tags);
create index if not exists website_faqs_active_idx on public.website_faqs(is_active, sort_order);
create index if not exists website_reviews_active_idx on public.website_reviews(is_active, published_at desc);

alter table public.website_blog_posts enable row level security;
alter table public.website_faqs enable row level security;
alter table public.website_reviews enable row level security;

create policy "public_read_published_blog_posts" on public.website_blog_posts for select using (is_published and published_at <= now());
create policy "admin_manage_blog_posts" on public.website_blog_posts for all using (public.is_admin()) with check (public.is_admin());
create policy "public_read_active_website_faqs" on public.website_faqs for select using (is_active);
create policy "admin_manage_website_faqs" on public.website_faqs for all using (public.is_admin()) with check (public.is_admin());
create policy "public_read_active_website_reviews" on public.website_reviews for select using (is_active);
create policy "admin_manage_website_reviews" on public.website_reviews for all using (public.is_admin()) with check (public.is_admin());

create trigger website_blog_posts_set_updated_at before update on public.website_blog_posts for each row execute function public.set_updated_at();
create trigger website_faqs_set_updated_at before update on public.website_faqs for each row execute function public.set_updated_at();
