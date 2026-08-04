import 'package:bookmyplatter/src/core/supabase/supabase_providers.dart';
import 'package:bookmyplatter/src/features/catalog/data/catalog_repository.dart';
import 'package:bookmyplatter/src/features/catalog/domain/category.dart';
import 'package:bookmyplatter/src/features/catalog/domain/package.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final websiteContentProvider = FutureProvider.family<String, ContentKind>((ref, kind) async {
  final key = switch (kind) {
    ContentKind.about => 'about_us',
    ContentKind.privacy => 'privacy_policy',
    ContentKind.terms => 'terms_and_conditions',
  };
  final row = await ref.watch(supabaseClientProvider).from('app_config').select('value').eq('key', key).maybeSingle();
  if (row == null) return '';
  final value = row['value'];
  if (value is String) return value;
  if (value is Map<String, dynamic>) return (value['content'] ?? value['text'] ?? '').toString();
  return value?.toString() ?? '';
});

enum ContentKind { about, privacy, terms }

final websiteCitiesProvider = FutureProvider<List<WebsiteCity>>((ref) async {
  final rows = await ref
      .watch(supabaseClientProvider)
      .from('cities')
      .select('name,slug')
      .eq('is_active', true)
      .order('name')
      .limit(30);
  return [for (final row in rows) WebsiteCity.fromMap(row)];
});

final websiteFaqsProvider = FutureProvider<List<WebsiteFaq>>((ref) async {
  final rows = await ref
      .watch(supabaseClientProvider)
      .from('website_faqs')
      .select('question,answer,category,sort_order')
      .eq('is_active', true)
      .order('sort_order')
      .limit(20);
  return [for (final row in rows) WebsiteFaq.fromMap(row)];
});

final websiteReviewsProvider = FutureProvider<List<WebsiteReview>>((ref) async {
  final rows = await ref
      .watch(supabaseClientProvider)
      .from('website_reviews')
      .select('customer_name,rating,review_text,source,city')
      .eq('is_active', true)
      .order('published_at', ascending: false)
      .limit(12);
  return [for (final row in rows) WebsiteReview.fromMap(row)];
});

final websiteBlogPostsProvider = FutureProvider<List<WebsiteBlogPost>>((ref) async {
  final rows = await ref
      .watch(supabaseClientProvider)
      .from('website_blog_posts')
      .select('slug,title,excerpt,category,tags,cover_image_url,published_at')
      .eq('is_published', true)
      .order('published_at', ascending: false)
      .limit(6);
  return [for (final row in rows) WebsiteBlogPost.fromMap(row)];
});

class WebsiteCity {
  const WebsiteCity({required this.name, required this.slug});
  factory WebsiteCity.fromMap(Map<String, dynamic> map) => WebsiteCity(name: map['name'] as String, slug: map['slug'] as String);
  final String name;
  final String slug;
}

class WebsiteFaq {
  const WebsiteFaq({required this.question, required this.answer, required this.category});
  factory WebsiteFaq.fromMap(Map<String, dynamic> map) => WebsiteFaq(question: map['question'] as String, answer: map['answer'] as String, category: map['category'] as String? ?? 'General');
  final String question;
  final String answer;
  final String category;
}

class WebsiteReview {
  const WebsiteReview({required this.customerName, required this.rating, required this.reviewText, required this.source, required this.city});
  factory WebsiteReview.fromMap(Map<String, dynamic> map) => WebsiteReview(customerName: map['customer_name'] as String, rating: (map['rating'] as num).toDouble(), reviewText: map['review_text'] as String, source: map['source'] as String? ?? 'Google', city: map['city'] as String? ?? '');
  final String customerName;
  final double rating;
  final String reviewText;
  final String source;
  final String city;
}


final websiteBlogPostProvider = FutureProvider.family<WebsiteBlogPostDetails, String>((ref, slug) async {
  final row = await ref
      .watch(supabaseClientProvider)
      .from('website_blog_posts')
      .select('slug,title,excerpt,content,category,tags,cover_image_url,meta_title,meta_description,canonical_url')
      .eq('slug', slug)
      .eq('is_published', true)
      .single();
  return WebsiteBlogPostDetails.fromMap(row);
});

class WebsiteBlogPostDetails extends WebsiteBlogPost {
  const WebsiteBlogPostDetails({
    required super.slug,
    required super.title,
    required super.excerpt,
    required super.category,
    required super.tags,
    required this.content,
    this.metaTitle,
    this.metaDescription,
    this.canonicalUrl,
    super.coverImageUrl,
  });

  factory WebsiteBlogPostDetails.fromMap(Map<String, dynamic> map) => WebsiteBlogPostDetails(
        slug: map['slug'] as String,
        title: map['title'] as String,
        excerpt: map['excerpt'] as String? ?? '',
        category: map['category'] as String? ?? 'Catering Guides',
        tags: List<String>.from((map['tags'] as List<dynamic>?) ?? const []),
        coverImageUrl: map['cover_image_url'] as String?,
        content: map['content'] as String,
        metaTitle: map['meta_title'] as String?,
        metaDescription: map['meta_description'] as String?,
        canonicalUrl: map['canonical_url'] as String?,
      );

  final String content;
  final String? metaTitle;
  final String? metaDescription;
  final String? canonicalUrl;
}

class WebsiteBlogPost {
  const WebsiteBlogPost({required this.slug, required this.title, required this.excerpt, required this.category, required this.tags, this.coverImageUrl});
  factory WebsiteBlogPost.fromMap(Map<String, dynamic> map) => WebsiteBlogPost(slug: map['slug'] as String, title: map['title'] as String, excerpt: map['excerpt'] as String? ?? '', category: map['category'] as String? ?? 'Catering Guides', tags: List<String>.from((map['tags'] as List<dynamic>?) ?? const []), coverImageUrl: map['cover_image_url'] as String?);
  final String slug;
  final String title;
  final String excerpt;
  final String category;
  final List<String> tags;
  final String? coverImageUrl;
}

class WebsiteHomePage extends ConsumerWidget {
  const WebsiteHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(bannersProvider);
    final packages = ref.watch(packagesProvider(const PackageQuery()));
    final vegPackages = ref.watch(packagesProvider(const PackageQuery(packageType: 'veg')));
    final nonVegPackages = ref.watch(packagesProvider(const PackageQuery(packageType: 'non_veg')));
    final platterBoxes = ref.watch(packagesProvider(const PackageQuery(packageType: 'platter_box')));
    final corporatePackages = ref.watch(packagesProvider(const PackageQuery(eventType: 'corporate')));
    final weddingPackages = ref.watch(packagesProvider(const PackageQuery(eventType: 'wedding')));
    final categories = ref.watch(categoriesProvider);
    final offers = ref.watch(marketplaceCollectionProvider('limited_offers'));
    final reviews = ref.watch(websiteReviewsProvider);
    final faqs = ref.watch(websiteFaqsProvider);
    final cities = ref.watch(websiteCitiesProvider);
    final blogs = ref.watch(websiteBlogPostsProvider);
    return Title(
      title: 'BookMyPlatter | Catering for Every Celebration',
      color: const Color(0xFF3C1285),
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(bannersProvider);
          ref.invalidate(packagesProvider);
          await ref.read(packagesProvider(const PackageQuery()).future);
        },
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _Hero(banners: banners, onRetry: () => ref.invalidate(bannersProvider))),
          SliverToBoxAdapter(child: _SearchPanel()),
          SliverToBoxAdapter(child: _CategorySection(categories: categories, onRetry: () => ref.invalidate(categoriesProvider))),
          SliverToBoxAdapter(child: _CollectionStrip(title: 'Limited & festival offers', items: offers, onRetry: () => ref.invalidate(marketplaceCollectionProvider('limited_offers')))),
          SliverToBoxAdapter(child: _PackageSection(title: 'Trending packages', packages: packages, onRetry: () => ref.invalidate(packagesProvider(const PackageQuery())))),
          SliverToBoxAdapter(child: _PackageSection(title: 'Veg catering packages', packages: vegPackages, onRetry: () => ref.invalidate(packagesProvider(const PackageQuery(packageType: 'veg'))))),
          SliverToBoxAdapter(child: _PackageSection(title: 'Non-veg catering packages', packages: nonVegPackages, onRetry: () => ref.invalidate(packagesProvider(const PackageQuery(packageType: 'non_veg'))))),
          SliverToBoxAdapter(child: _PackageSection(title: 'Platter boxes', packages: platterBoxes, onRetry: () => ref.invalidate(packagesProvider(const PackageQuery(packageType: 'platter_box'))))),
          SliverToBoxAdapter(child: _PackageSection(title: 'Corporate catering', packages: corporatePackages, onRetry: () => ref.invalidate(packagesProvider(const PackageQuery(eventType: 'corporate'))))),
          SliverToBoxAdapter(child: _PackageSection(title: 'Wedding catering', packages: weddingPackages, onRetry: () => ref.invalidate(packagesProvider(const PackageQuery(eventType: 'wedding'))))),
          const SliverToBoxAdapter(child: _WhyBookMyPlatter()),
          SliverToBoxAdapter(child: _TestimonialsSection(reviews: reviews, onRetry: () => ref.invalidate(websiteReviewsProvider))),
          SliverToBoxAdapter(child: _CitiesSection(cities: cities, onRetry: () => ref.invalidate(websiteCitiesProvider))),
          SliverToBoxAdapter(child: _FaqSection(faqs: faqs, onRetry: () => ref.invalidate(websiteFaqsProvider))),
          SliverToBoxAdapter(child: _BlogSection(posts: blogs, onRetry: () => ref.invalidate(websiteBlogPostsProvider))),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ]),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.banners, required this.onRetry});
  final AsyncValue<List<HeroBanner>> banners;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: MediaQuery.sizeOf(context).width < 700 ? 430 : 520,
        child: banners.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorPanel(message: 'Promotions could not be loaded', onRetry: onRetry),
          data: (items) {
            final banner = items.isEmpty ? null : items.first;
            return Stack(fit: StackFit.expand, children: [
              if (banner?.imageUrl != null)
                CachedNetworkImage(imageUrl: banner!.imageUrl!, fit: BoxFit.cover, fadeInDuration: const Duration(milliseconds: 250)),
              DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFF250653).withOpacity(.96), const Color(0xFF3C1285).withOpacity(.58), Colors.transparent]))),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 620,
                        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Chip(label: Text('Premium catering • Live availability')),
                          const SizedBox(height: 18),
                          Text(banner?.title ?? 'Celebrate beautifully with BookMyPlatter', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 14),
                          Text(banner?.subtitle ?? 'Curated menus, transparent pricing, secure checkout, and live booking updates.', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                          const SizedBox(height: 28),
                          FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF5B300), foregroundColor: Colors.black87), onPressed: () => context.go('/planner'), icon: const Icon(Icons.auto_awesome), label: const Text('Plan my event')),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ]);
          },
        ),
      );
}

class PackageListingPage extends ConsumerWidget {
  const PackageListingPage({required this.type, required this.title, super.key});
  final String type;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = PackageQuery(packageType: type);
    final packages = ref.watch(packagesProvider(query));
    return Title(
      title: '$title | BookMyPlatter',
      color: const Color(0xFF3C1285),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: _Section(
          title: title,
          subtitle: 'Live availability and pricing managed by BookMyPlatter.',
          child: packages.when(
            loading: () => const _PackageSkeleton(),
            error: (error, _) => _ErrorPanel(message: 'Packages could not be loaded', onRetry: () => ref.invalidate(packagesProvider(query))),
            data: (items) => items.isEmpty
                ? const _EmptyPanel(message: 'No packages are currently available in this collection.')
                : _PackageGrid(items: items),
          ),
        ),
      ),
    );
  }
}

class ContentPage extends ConsumerWidget {
  const ContentPage({required this.kind, super.key});
  final ContentKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heading = switch (kind) { ContentKind.about => 'About BookMyPlatter', ContentKind.privacy => 'Privacy Policy', ContentKind.terms => 'Terms & Conditions' };
    final content = ref.watch(websiteContentProvider(kind));
    return Title(
      title: '$heading | BookMyPlatter',
      color: const Color(0xFF3C1285),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: _Section(
          title: heading,
          subtitle: kind == ContentKind.about ? 'Single-brand catering, thoughtfully designed for memorable events.' : 'The latest policy published by BookMyPlatter.',
          child: content.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => _ErrorPanel(message: 'This content could not be loaded', onRetry: () => ref.invalidate(websiteContentProvider(kind))),
            data: (text) => text.trim().isEmpty
                ? const _EmptyPanel(message: 'This content has not been published yet. Please contact BookMyPlatter for assistance.')
                : SelectableText(text, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7)),
          ),
        ),
      ),
    );
  }
}

class _PackageSection extends StatelessWidget {
  const _PackageSection({required this.title, required this.packages, required this.onRetry});
  final String title;
  final AsyncValue<List<CateringPackage>> packages;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => _Section(
        title: title,
        subtitle: 'Customer favourites ranked from the live catalog.',
        child: packages.when(
          loading: () => const _PackageSkeleton(),
          error: (error, _) => _ErrorPanel(message: 'Packages could not be loaded', onRetry: onRetry),
          data: (items) => items.isEmpty ? const _EmptyPanel(message: 'No packages are available right now.') : _PackageGrid(items: items.take(8).toList()),
        ),
      );
}

class _PackageGrid extends StatelessWidget {
  const _PackageGrid({required this.items});
  final List<CateringPackage> items;
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1150 ? 4 : width >= 720 ? 2 : 1;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 18, mainAxisSpacing: 18, childAspectRatio: columns == 1 ? 1.35 : .78),
      itemCount: items.length,
      itemBuilder: (context, index) => _PackageCard(package: items[index]),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.package});
  final CateringPackage package;
  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go('/package/${package.id}'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: package.imageUrl == null
                    ? const ColoredBox(color: Color(0xFFF1ECF8), child: Icon(Icons.restaurant, size: 56))
                    : CachedNetworkImage(imageUrl: package.imageUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 6, children: [Chip(label: Text(package.isVeg ? 'VEG' : 'NON-VEG'), visualDensity: VisualDensity.compact), if (package.rating > 0) Chip(avatar: const Icon(Icons.star, size: 16), label: Text(package.rating.toStringAsFixed(1)), visualDensity: VisualDensity.compact)]),
                const SizedBox(height: 6),
                Text(package.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('₹${package.pricePerGuest.toStringAsFixed(0)} per guest • ${package.minGuests}-${package.maxGuests} guests'),
              ]),
            ),
          ]),
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 22),
              child,
            ]),
          ),
        ),
      );
}

class _PackageSkeleton extends StatelessWidget {
  const _PackageSkeleton();
  @override
  Widget build(BuildContext context) => const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()));
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off_outlined, size: 40), const SizedBox(height: 8), Text(message), if (onRetry != null) TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry'))]));
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(28), child: Row(children: [const Icon(Icons.info_outline), const SizedBox(width: 12), Expanded(child: Text(message))])));
}

class _SearchPanel extends StatefulWidget {
  @override
  State<_SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<_SearchPanel> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Section(
        title: 'Find catering for any celebration',
        subtitle: 'Search packages, cuisines, cities or event types across live BookMyPlatter inventory.',
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Search wedding, corporate, platter boxes...',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: _search,
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _search(controller.text),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Search'),
            ),
          ],
        ),
      );

  void _search(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    context.go('/search?q=${Uri.encodeQueryComponent(query)}');
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.categories, required this.onRetry});
  final AsyncValue<List<Category>> categories;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _Section(
        title: 'Explore categories',
        subtitle: 'Browse live categories managed from the shared Supabase catalog.',
        child: categories.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => _ErrorPanel(message: 'Categories could not be loaded', onRetry: onRetry),
          data: (items) => items.isEmpty
              ? const _EmptyPanel(message: 'No categories are published yet.')
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final item in items)
                      ActionChip(
                        avatar: Text(item.icon),
                        label: Text(item.name),
                        onPressed: () => context.go('/search?category=${item.id}'),
                      ),
                  ],
                ),
        ),
      );
}

class _CollectionStrip extends StatelessWidget {
  const _CollectionStrip({required this.title, required this.items, required this.onRetry});
  final String title;
  final AsyncValue<List<MarketplaceContentItem>> items;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _Section(
        title: title,
        subtitle: 'Campaigns, offers and landing blocks are controlled by the admin CMS.',
        child: items.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => _ErrorPanel(message: 'Offers could not be loaded', onRetry: onRetry),
          data: (rows) => rows.isEmpty
              ? const _EmptyPanel(message: 'No active offers are published right now.')
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final item in rows)
                        SizedBox(
                          width: 280,
                          child: Card(
                            child: ListTile(
                              leading: Text(item.icon, style: const TextStyle(fontSize: 28)),
                              title: Text(item.title),
                              subtitle: Text(item.subtitle),
                              onTap: () => context.go(item.route ?? '/search?q=${Uri.encodeQueryComponent(item.searchQuery ?? item.title)}'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      );
}

class _WhyBookMyPlatter extends StatelessWidget {
  const _WhyBookMyPlatter();

  @override
  Widget build(BuildContext context) => _Section(
        title: 'Why BookMyPlatter',
        subtitle: 'A synchronized marketplace, CRM and operations backend built for Indian catering bookings.',
        child: Wrap(
          spacing: 14,
          runSpacing: 14,
          children: const [
            _ValueCard(icon: Icons.verified, title: 'Verified caterers', text: 'Catalog, reviews and operations managed through Supabase.'),
            _ValueCard(icon: Icons.currency_rupee, title: 'Transparent pricing', text: 'Per-guest pricing, menu customisation and checkout estimates.'),
            _ValueCard(icon: Icons.sms_outlined, title: 'SMS + WhatsApp', text: 'Fast2SMS and WhatsApp templates keep customers updated.'),
            _ValueCard(icon: Icons.timeline, title: 'Realtime tracking', text: 'Customer, admin and website data stay synchronized.'),
          ],
        ),
      );
}

class _ValueCard extends StatelessWidget {
  const _ValueCard({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 270,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(text),
            ]),
          ),
        ),
      );
}

class _TestimonialsSection extends StatelessWidget {
  const _TestimonialsSection({required this.reviews, required this.onRetry});
  final AsyncValue<List<WebsiteReview>> reviews;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _Section(
        title: 'Google reviews & testimonials',
        subtitle: 'Published customer trust signals from the website CMS.',
        child: reviews.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => _ErrorPanel(message: 'Reviews could not be loaded', onRetry: onRetry),
          data: (items) => items.isEmpty
              ? const _EmptyPanel(message: 'No reviews are published yet.')
              : Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final item in items)
                      SizedBox(
                        width: 360,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${item.rating.toStringAsFixed(1)} ★ • ${item.source}', style: Theme.of(context).textTheme.labelLarge),
                              const SizedBox(height: 8),
                              Text(item.reviewText),
                              const SizedBox(height: 10),
                              Text('${item.customerName}${item.city.isEmpty ? '' : ' • ${item.city}'}'),
                            ]),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      );
}

class _CitiesSection extends StatelessWidget {
  const _CitiesSection({required this.cities, required this.onRetry});
  final AsyncValue<List<WebsiteCity>> cities;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _Section(
        title: 'Cities we serve',
        subtitle: 'Active service cities from the shared marketplace backend.',
        child: cities.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => _ErrorPanel(message: 'Cities could not be loaded', onRetry: onRetry),
          data: (items) => items.isEmpty
              ? const _EmptyPanel(message: 'No cities are published yet.')
              : Wrap(spacing: 10, runSpacing: 10, children: [for (final city in items) ActionChip(label: Text(city.name), onPressed: () => context.go('/search?q=${Uri.encodeQueryComponent(city.name)}'))]),
        ),
      );
}

class _FaqSection extends StatelessWidget {
  const _FaqSection({required this.faqs, required this.onRetry});
  final AsyncValue<List<WebsiteFaq>> faqs;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _Section(
        title: 'Frequently asked questions',
        subtitle: 'FAQ content is managed from Supabase and can be reused by admin, website and app.',
        child: faqs.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => _ErrorPanel(message: 'FAQs could not be loaded', onRetry: onRetry),
          data: (items) => items.isEmpty
              ? const _EmptyPanel(message: 'No FAQs are published yet.')
              : Column(children: [for (final item in items) Card(child: ExpansionTile(title: Text(item.question), subtitle: Text(item.category), children: [Padding(padding: const EdgeInsets.all(16), child: Align(alignment: Alignment.centerLeft, child: Text(item.answer)))]])),
        ),
      );
}

class _BlogSection extends StatelessWidget {
  const _BlogSection({required this.posts, required this.onRetry});
  final AsyncValue<List<WebsiteBlogPost>> posts;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _Section(
        title: 'Catering guides & blogs',
        subtitle: 'SEO-ready blog posts with categories, tags, schema and canonical metadata.',
        child: posts.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => _ErrorPanel(message: 'Blogs could not be loaded', onRetry: onRetry),
          data: (items) => items.isEmpty
              ? const _EmptyPanel(message: 'No blogs are published yet.')
              : Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final post in items)
                      SizedBox(
                        width: 360,
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => context.go('/blog/${post.slug}'),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              if (post.coverImageUrl != null) CachedNetworkImage(imageUrl: post.coverImageUrl!, height: 170, width: double.infinity, fit: BoxFit.cover),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(post.category, style: Theme.of(context).textTheme.labelLarge),
                                  const SizedBox(height: 6),
                                  Text(post.title, style: Theme.of(context).textTheme.titleMedium),
                                  const SizedBox(height: 6),
                                  Text(post.excerpt, maxLines: 3, overflow: TextOverflow.ellipsis),
                                ]),
                              ),
                            ]),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      );
}

class BlogDetailsPage extends ConsumerWidget {
  const BlogDetailsPage({required this.slug, super.key});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = ref.watch(websiteBlogPostProvider(slug));
    return post.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _Section(
        title: 'Blog unavailable',
        subtitle: 'The requested article could not be loaded.',
        child: _ErrorPanel(message: error.toString(), onRetry: () => ref.invalidate(websiteBlogPostProvider(slug))),
      ),
      data: (item) => Title(
        title: '${item.metaTitle ?? item.title} | BookMyPlatter',
        color: const Color(0xFF3C1285),
        child: SingleChildScrollView(
          child: _Section(
            title: item.title,
            subtitle: item.metaDescription ?? item.excerpt,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.coverImageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: CachedNetworkImage(imageUrl: item.coverImageUrl!, width: double.infinity, height: 360, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 20),
                Wrap(spacing: 8, children: [for (final tag in item.tags) Chip(label: Text(tag))]),
                const SizedBox(height: 20),
                SelectableText(item.content, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7)),
                const SizedBox(height: 24),
                FilledButton.icon(onPressed: () => context.go('/search'), icon: const Icon(Icons.search), label: const Text('Browse catering packages')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RobotsPage extends StatelessWidget {
  const RobotsPage({super.key});

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: SelectableText('User-agent: *\nAllow: /\nSitemap: /sitemap.xml'),
        ),
      );
}

class SitemapPage extends ConsumerWidget {
  const SitemapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(websiteBlogPostsProvider).valueOrNull ?? const <WebsiteBlogPost>[];
    final urls = [
      '/',
      '/packages/veg',
      '/packages/non-veg',
      '/packages/platter-box',
      '/packages/catering-combos',
      '/about',
      '/privacy',
      '/terms',
      for (final post in posts) '/blog/${post.slug}',
    ];
    final xml = StringBuffer('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n');
    for (final url in urls) {
      xml.writeln('  <url><loc>$url</loc></url>');
    }
    xml.write('</urlset>');
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SelectableText(xml.toString()),
      ),
    );
  }
}
