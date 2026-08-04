import 'dart:async';
import 'package:bookmyplatter/src/features/address/application/address_controller.dart';
import 'package:bookmyplatter/src/features/address/domain/address.dart';
import 'package:bookmyplatter/src/features/assistant/application/catering_assistant_controller.dart';
import 'package:bookmyplatter/src/features/auth/data/auth_repository.dart';
import 'package:bookmyplatter/src/features/cart/application/cart_controller.dart';
import 'package:bookmyplatter/src/features/catalog/data/catalog_repository.dart';
import 'package:bookmyplatter/src/features/catalog/domain/category.dart';
import 'package:bookmyplatter/src/features/catalog/domain/package.dart';
import 'package:bookmyplatter/src/features/favorites/application/favorites_controller.dart';
import 'package:bookmyplatter/src/features/notifications/application/notification_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _purple = Color(0xFF4B1E83);
const _gold = Color(0xFFD4AF37);
const _surfaceGold = Color(0xFFFFF8E1);
const _softPurple = Color(0xFFF3EDFF);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _heroController = PageController(viewportFraction: .92);
  Timer? _heroTimer;

  @override
  void initState() {
    super.initState();
    _heroTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_heroController.hasClients) return;
      final nextPage = (_heroController.page?.round() ?? 0) + 1;
      _heroController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref
      ..invalidate(categoriesProvider)
      ..invalidate(bannersProvider)
      ..invalidate(packagesProvider)
      ..invalidate(recentlyViewedPackagesProvider)
      ..invalidate(favoritesControllerProvider)
      ..invalidate(notificationControllerProvider)
      ..invalidate(marketplaceCollectionProvider)
      ..invalidate(customerReviewHighlightsProvider);
    await Future.wait([
      ref.read(categoriesProvider.future),
      ref.read(bannersProvider.future),
      ref.read(packagesProvider(const PackageQuery()).future),
      ref.read(
        packagesProvider(const PackageQuery(sort: PackageSort.rating)).future,
      ),
      ref.read(recentlyViewedPackagesProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final banners = ref.watch(bannersProvider);
    final featured = ref.watch(packagesProvider(const PackageQuery()));
    final topRated = ref.watch(
      packagesProvider(const PackageQuery(sort: PackageSort.rating)),
    );
    final platterBoxes = ref.watch(
      packagesProvider(const PackageQuery(packageType: 'platter_box')),
    );
    final recentlyViewed = ref.watch(recentlyViewedPackagesProvider);
    final favoritesState = ref.watch(favoritesControllerProvider);
    final favorites = favoritesState.valueOrNull ?? const <String>{};
    final bookingDraft = ref.watch(cateringAssistantControllerProvider).valueOrNull;
    final user = ref.watch(authRepositoryProvider).currentUser;
    final notifications = ref.watch(unreadNotificationCountProvider);
    final cartCount = ref.watch(cartControllerProvider).length;
    final addresses = ref.watch(addressControllerProvider).valueOrNull;
    final firstName = _firstName(user?.userMetadata?['full_name'] as String?);
    final occasions = ref.watch(marketplaceCollectionProvider('occasions'));
    final popularMenus = ref.watch(marketplaceCollectionProvider('popular_menus'));
    final trustItems = ref.watch(marketplaceCollectionProvider('why_bookmyplatter'));
    final planningTips = ref.watch(marketplaceCollectionProvider('planning_tips'));
    final faqs = ref.watch(marketplaceCollectionProvider('faqs'));
    final reviewHighlights = ref.watch(customerReviewHighlightsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _MarketplaceAppBar(
        firstName: firstName,
        unreadCount: notifications,
        cartCount: cartCount,
        locationLabel: _locationLabel(addresses),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: _purple,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SearchAndAssistantBar(bookingDraft: bookingDraft),
                        const SizedBox(height: 18),
                        _HeroBannerCarousel(
                          banners: banners,
                          controller: _heroController,
                        ),
                        const SizedBox(height: 24),
                        _QuickCategories(categories: categories),
                        const SizedBox(height: 28),
                        _OccasionCards(items: occasions),
                        const SizedBox(height: 28),
                        _AsyncPackageSection(
                          title: 'Featured packages',
                          subtitle: 'Curated live packages for every budget',
                          packages: featured,
                          favorites: favorites,
                          onAdd: _addToCart,
                          onFavorite: _toggleFavorite,
                        ),
                        const SizedBox(height: 28),
                        _TrendingCaterers(packages: featured),
                        const SizedBox(height: 28),
                        _PopularMenus(items: popularMenus),
                        const SizedBox(height: 28),
                        _HorizontalPackageSection(
                          title: 'Platter Box specials',
                          subtitle: 'Ready-to-serve boxes for office and family meals',
                          packages: platterBoxes,
                          fallback: featured,
                          favorites: favorites,
                          onAdd: _addToCart,
                          onFavorite: _toggleFavorite,
                        ),
                        const SizedBox(height: 28),
                        _HorizontalPackageSection(
                          title: 'Recommended for you',
                          subtitle: _recommendationSubtitle(bookingDraft),
                          packages: recentlyViewed,
                          fallback: featured,
                          favorites: favorites,
                          onAdd: _addToCart,
                          onFavorite: _toggleFavorite,
                        ),
                        const SizedBox(height: 28),
                        _AsyncPackageSection(
                          title: 'Top rated this week',
                          subtitle: 'Highest-rated packages from verified caterers',
                          packages: topRated,
                          favorites: favorites,
                          onAdd: _addToCart,
                          onFavorite: _toggleFavorite,
                          compact: true,
                        ),
                        const SizedBox(height: 28),
                        _TodaysOffers(banners: banners, packages: featured),
                        const SizedBox(height: 28),
                        _NearbyCaterers(packages: featured),
                        const SizedBox(height: 28),
                        _ReviewsCarousel(reviews: reviewHighlights),
                        const SizedBox(height: 28),
                        _WhyBookMyPlatter(items: trustItems),
                        const SizedBox(height: 28),
                        const _DownloadAppBanner(),
                        const SizedBox(height: 18),
                        const _ReferralBanner(),
                        const SizedBox(height: 28),
                        _BlogAndTips(items: planningTips),
                        const SizedBox(height: 28),
                        _Faqs(items: faqs),
                        const SizedBox(height: 28),
                        const _ContactSupport(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _locationLabel(List<Address>? addresses) {
    Address? selected;
    if (addresses != null && addresses.isNotEmpty) {
      for (final address in addresses) {
        if (address.isDefault) {
          selected = address;
          break;
        }
      }
      selected ??= addresses.first;
    }
    if (selected == null) return 'Select event location';
    return selected.label.isNotEmpty ? selected.label : selected.line1;
  }

  String? _firstName(String? fullName) {
    final normalized = fullName?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized.split(RegExp(r'\s+')).first;
  }

  String _recommendationSubtitle(CateringAssistantState? draft) {
    if (draft == null || !draft.hasProgress) {
      return 'Based on popular choices and your recent views';
    }
    return 'Based on your ${draft.guestCount}-guest planning draft';
  }

  void _addToCart(CateringPackage package) {
    ref.read(cartControllerProvider.notifier).addPackage(package);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${package.name} added to cart'),
        action: SnackBarAction(
          label: 'View cart',
          onPressed: () => context.go('/cart'),
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(String packageId) async {
    try {
      await ref.read(favoritesControllerProvider.notifier).toggle(packageId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save favorites')),
      );
    }
  }
}

class _MarketplaceAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _MarketplaceAppBar({
    required this.firstName,
    required this.unreadCount,
    required this.cartCount,
    required this.locationLabel,
  });

  final String? firstName;
  final int unreadCount;
  final int cartCount;
  final String locationLabel;

  @override
  Size get preferredSize => const Size.fromHeight(116);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: _purple,
      surfaceTintColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => context.go('/addresses'),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: _softPurple,
                            child: Icon(Icons.location_on_rounded, color: _purple),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Delivering to',
                                  style: TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                                Text(
                                  locationLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: _purple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _BadgeIconButton(
                    icon: Icons.notifications_none_rounded,
                    count: unreadCount,
                    onPressed: () => context.go('/notifications'),
                  ),
                  _BadgeIconButton(
                    icon: Icons.shopping_cart_outlined,
                    count: cartCount,
                    onPressed: () => context.go('/cart'),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => context.go('/profile'),
                    icon: Text(
                      (firstName?.isNotEmpty ?? false) ? firstName![0].toUpperCase() : 'B',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const _LiveSearchBar(),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveSearchBar extends ConsumerStatefulWidget {
  const _LiveSearchBar();

  @override
  ConsumerState<_LiveSearchBar> createState() => _LiveSearchBarState();
}

class _LiveSearchBarState extends ConsumerState<_LiveSearchBar> {
  final controller = SearchController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      searchController: controller,
      builder: (context, controller) {
        return SearchBar(
          controller: controller,
          hintText: 'Search caterers, menus, occasions',
          leading: const Icon(Icons.search_rounded),
          trailing: const [Icon(Icons.tune_rounded)],
          onTap: controller.openView,
          onChanged: (_) => controller.openView(),
          onSubmitted: (value) => context.go('/search?q=${Uri.encodeComponent(value)}'),
        );
      },
      suggestionsBuilder: (context, controller) {
        final query = controller.text.trim();
        final suggestions = ref.watch(searchSuggestionsProvider(query));
        return suggestions.when(
          loading: () => const [
            ListTile(leading: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)), title: Text('Searching live marketplace...')),
          ],
          error: (_, __) => const [
            ListTile(leading: Icon(Icons.error_outline), title: Text('Suggestions unavailable')),
          ],
          data: (items) {
            if (query.length < 2) {
              return const [
                ListTile(leading: Icon(Icons.search_rounded), title: Text('Type at least 2 characters')),
              ];
            }
            if (items.isEmpty) {
              return [
                ListTile(
                  leading: const Icon(Icons.manage_search_rounded),
                  title: Text('Search for "$query"'),
                  onTap: () => context.go('/search?q=${Uri.encodeComponent(query)}'),
                ),
              ];
            }
            return [
              for (final item in items)
                ListTile(
                  leading: Text(item.icon),
                  title: Text(item.label),
                  onTap: () => context.go(item.route),
                ),
            ];
          },
        );
      },
    );
  }
}

class _BadgeIconButton extends StatelessWidget {
  const _BadgeIconButton({
    required this.icon,
    required this.count,
    required this.onPressed,
  });

  final IconData icon;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(onPressed: onPressed, icon: Icon(icon)),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _gold,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchAndAssistantBar extends StatelessWidget {
  const _SearchAndAssistantBar({required this.bookingDraft});

  final CateringAssistantState? bookingDraft;

  @override
  Widget build(BuildContext context) {
    final hasDraft = bookingDraft?.hasProgress ?? false;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: Card(
        key: ValueKey(hasDraft),
        color: hasDraft ? _softPurple : _purple,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          leading: CircleAvatar(
            backgroundColor: hasDraft ? _purple : _gold,
            child: Icon(
              hasDraft ? Icons.history_rounded : Icons.auto_awesome_rounded,
              color: hasDraft ? Colors.white : Colors.black,
            ),
          ),
          title: Text(
            hasDraft ? 'Continue your event plan' : 'Plan your catering with AI',
            style: TextStyle(
              color: hasDraft ? _purple : Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Text(
            hasDraft ? _draftSummary(bookingDraft!) : 'Tell us the occasion, guests, and menu style',
            style: TextStyle(color: hasDraft ? Colors.black87 : Colors.white70),
          ),
          trailing: Icon(
            Icons.arrow_forward_rounded,
            color: hasDraft ? _purple : Colors.white,
          ),
          onTap: () => context.go('/assistant'),
        ),
      ),
    );
  }

  String _draftSummary(CateringAssistantState draft) {
    final details = <String>[
      if (draft.eventType != null) draft.eventType!.replaceAll('_', ' '),
      '${draft.guestCount} guests',
      if (draft.foodPreference != null) draft.foodPreference!.replaceAll('_', '-'),
    ];
    return details.join(' • ');
  }
}

class _HeroBannerCarousel extends StatelessWidget {
  const _HeroBannerCarousel({required this.banners, required this.controller});

  final AsyncValue<List<HeroBanner>> banners;
  final PageController controller;

  @override
  Widget build(BuildContext context) {
    return banners.when(
      loading: () => const _HeroSkeleton(),
      error: (_, __) => _HeroFallback(onTap: () => context.go('/search')),
      data: (items) {
        final liveBanners = items.isEmpty ? null : items;
        if (liveBanners == null) return _HeroFallback(onTap: () => context.go('/search'));
        return SizedBox(
          height: _isWide(context) ? 290 : 214,
          child: PageView.builder(
            controller: controller,
            itemBuilder: (context, index) {
              final banner = liveBanners[index % liveBanners.length];
              return _AnimatedIn(
                delay: Duration(milliseconds: 80 * (index % liveBanners.length)),
                child: _HeroBannerCard(banner: banner),
              );
            },
          ),
        );
      },
    );
  }
}

class _HeroBannerCard extends StatelessWidget {
  const _HeroBannerCard({required this.banner});

  final HeroBanner banner;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: InkWell(
          onTap: () => context.go('/search?q=${Uri.encodeComponent(banner.title)}'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (banner.imageUrl != null)
                CachedNetworkImage(imageUrl: banner.imageUrl!, fit: BoxFit.cover)
              else
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_purple, Color(0xFF7C3FBC), _gold],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(.72), Colors.transparent],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      banner.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      banner.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.tonalIcon(
                      onPressed: () => context.go('/search?q=${Uri.encodeComponent(banner.title)}'),
                      icon: const Icon(Icons.celebration_rounded),
                      label: const Text('Explore offer'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _isWide(context) ? 290 : 214,
      child: Card(
        color: _purple,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Premium catering for every celebration',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Wedding, corporate, birthday, and platter boxes from verified caterers.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(onPressed: onTap, child: const Text('Start booking')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickCategories extends StatelessWidget {
  const _QuickCategories({required this.categories});

  final AsyncValue<List<Category>> categories;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'Quick categories',
      subtitle: 'Jump into popular catering styles',
      child: categories.when(
        loading: () => const _HorizontalSkeleton(height: 74),
        error: (_, __) => const _InlineError(message: 'Unable to load categories'),
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyLiveData(
              icon: Icons.category_outlined,
              title: 'Categories are being configured',
              message: 'Pull to refresh after active categories are published.',
            );
          }
          final chips = items;
          return SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final category = chips[index];
                return _AnimatedIn(
                  delay: Duration(milliseconds: 35 * index),
                  child: _CategoryPill(category: category),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Text(category.icon),
      label: Text(category.name),
      labelStyle: const TextStyle(fontWeight: FontWeight.w800),
      backgroundColor: _softPurple,
      side: BorderSide(color: _purple.withOpacity(.08)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onPressed: () {
        final isSupabaseId = RegExp(
          r'^[0-9a-fA-F-]{36}$',
        ).hasMatch(category.id);
        final query = Uri.encodeComponent(category.name);
        context.go(isSupabaseId ? '/search?category=${category.id}' : '/search?q=$query');
      },
    );
  }
}

class _OccasionCards extends StatelessWidget {
  const _OccasionCards({required this.items});

  final AsyncValue<List<MarketplaceContentItem>> items;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'Shop by occasion',
      subtitle: 'Menus tuned for your event format',
      child: items.when(
        loading: () => const _HorizontalSkeleton(height: 180),
        error: (_, __) => const _InlineError(message: 'Unable to load occasions'),
        data: (liveItems) {
          if (liveItems.isEmpty) {
            return const _EmptyLiveData(
              icon: Icons.celebration_outlined,
              title: 'Occasions are being configured',
              message: 'Publish marketplace occasion content in Supabase.',
            );
          }
          return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = width > 900 ? 5 : width > 620 ? 4 : 3;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: liveItems.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: width > 620 ? 1.9 : 1.18,
            ),
            itemBuilder: (context, index) {
              final occasion = liveItems[index];
              return _AnimatedIn(
                delay: Duration(milliseconds: 35 * index),
                child: _OccasionTile(occasion: occasion),
              );
            },
          );
        },
          );
        },
      ),
    );
  }
}

class _OccasionTile extends StatelessWidget {
  const _OccasionTile({required this.occasion});

  final MarketplaceContentItem occasion;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: _surfaceGold,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.go(_routeForContent(occasion)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(occasion.icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 8),
              Text(
                occasion.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AsyncPackageSection extends StatelessWidget {
  const _AsyncPackageSection({
    required this.title,
    required this.subtitle,
    required this.packages,
    required this.favorites,
    required this.onAdd,
    required this.onFavorite,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final AsyncValue<List<CateringPackage>> packages;
  final Set<String> favorites;
  final ValueChanged<CateringPackage> onAdd;
  final ValueChanged<String> onFavorite;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: title,
      subtitle: subtitle,
      actionLabel: 'View all',
      onAction: () => context.go('/search'),
      child: packages.when(
        loading: () => _PackageSkeletonGrid(compact: compact),
        error: (_, __) => const _InlineError(message: 'Unable to load packages'),
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyLiveData(
              icon: Icons.restaurant_menu_rounded,
              title: 'Packages are being refreshed',
              message: 'Please pull to refresh or try another category.',
            );
          }
          final visible = items.take(compact ? 4 : 6).toList(growable: false);
          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 900 ? 3 : constraints.maxWidth > 620 ? 2 : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visible.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: columns == 1 ? 1.02 : .82,
                ),
                itemBuilder: (context, index) {
                  final package = visible[index];
                  return _AnimatedIn(
                    delay: Duration(milliseconds: 55 * index),
                    child: _PackageCard(
                      package: package,
                      isFavorite: favorites.contains(package.id),
                      onAdd: () => onAdd(package),
                      onFavorite: () => onFavorite(package.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _HorizontalPackageSection extends StatelessWidget {
  const _HorizontalPackageSection({
    required this.title,
    required this.subtitle,
    required this.packages,
    required this.fallback,
    required this.favorites,
    required this.onAdd,
    required this.onFavorite,
  });

  final String title;
  final String subtitle;
  final AsyncValue<List<CateringPackage>> packages;
  final AsyncValue<List<CateringPackage>> fallback;
  final Set<String> favorites;
  final ValueChanged<CateringPackage> onAdd;
  final ValueChanged<String> onFavorite;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: title,
      subtitle: subtitle,
      actionLabel: 'Explore',
      onAction: () => context.go('/search'),
      child: packages.when(
        loading: () => const _HorizontalSkeleton(height: 292),
        error: (_, __) => _horizontalList(context, fallback.valueOrNull ?? const []),
        data: (items) {
          final visible = items.isEmpty ? fallback.valueOrNull ?? const <CateringPackage>[] : items;
          if (visible.isEmpty) {
            return const _EmptyLiveData(
              icon: Icons.inventory_2_outlined,
              title: 'Fresh recommendations are loading',
              message: 'Pull to refresh after your caterers publish new packages.',
            );
          }
          return _horizontalList(context, visible.take(10).toList(growable: false));
        },
      ),
    );
  }

  Widget _horizontalList(BuildContext context, List<CateringPackage> items) {
    if (items.isEmpty) return const _HorizontalSkeleton(height: 292);
    return SizedBox(
      height: 306,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final package = items[index];
          return SizedBox(
            width: 254,
            child: _PackageCard(
              package: package,
              isFavorite: favorites.contains(package.id),
              onAdd: () => onAdd(package),
              onFavorite: () => onFavorite(package.id),
            ),
          );
        },
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.isFavorite,
    required this.onAdd,
    required this.onFavorite,
  });

  final CateringPackage package;
  final bool isFavorite;
  final VoidCallback onAdd;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.black.withOpacity(.06)),
      ),
      child: InkWell(
        onTap: () => context.go('/package/${package.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'package-${package.id}',
                    child: _NetworkOrGradientImage(
                      imageUrl: package.imageUrl,
                      icon: Icons.room_service_rounded,
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: _VegBadge(isVeg: package.isVeg),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton.filledTonal(
                      onPressed: onFavorite,
                      icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    package.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _RatingPill(rating: package.rating),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${package.minGuests}-${package.maxGuests} guests',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: '₹${package.pricePerGuest.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: _purple,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                            children: const [
                              TextSpan(
                                text: ' / plate',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: onAdd,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendingCaterers extends StatelessWidget {
  const _TrendingCaterers({required this.packages});

  final AsyncValue<List<CateringPackage>> packages;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'Trending caterers',
      subtitle: 'Caterers customers are booking right now',
      actionLabel: 'Book now',
      onAction: () => context.go('/search'),
      child: packages.when(
        loading: () => const _HorizontalSkeleton(height: 224),
        error: (_, __) => const _InlineError(message: 'Unable to load caterers'),
        data: (items) {
          final grouped = _groupByVendor(items).take(8).toList(growable: false);
          if (grouped.isEmpty) {
            return const _EmptyLiveData(
              icon: Icons.storefront_outlined,
              title: 'No caterers available yet',
              message: 'Pull to refresh as verified caterers publish packages.',
            );
          }
          return SizedBox(
            height: 236,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: grouped.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) => _CatererCard(summary: grouped[index]),
            ),
          );
        },
      ),
    );
  }

  Iterable<_CatererSummary> _groupByVendor(List<CateringPackage> packages) sync* {
    final byVendor = <String, List<CateringPackage>>{};
    for (final package in packages) {
      byVendor.putIfAbsent(package.vendorId, () => []).add(package);
    }
    for (final entry in byVendor.entries) {
      final vendorPackages = entry.value;
      vendorPackages.sort((a, b) => b.rating.compareTo(a.rating));
      final best = vendorPackages.first;
      yield _CatererSummary(
        title: best.name,
        coverImage: best.imageUrl,
        rating: vendorPackages
            .map((item) => item.rating)
            .reduce((left, right) => left > right ? left : right),
        startingPrice: vendorPackages
            .map((item) => item.pricePerGuest)
            .reduce((left, right) => left < right ? left : right),
        packageCount: vendorPackages.length,
      );
    }
  }
}

class _CatererCard extends StatelessWidget {
  const _CatererCard({required this.summary});

  final _CatererSummary summary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 302,
      child: Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: InkWell(
          onTap: () => context.go('/search?q=${Uri.encodeComponent(summary.title)}'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _NetworkOrGradientImage(
                imageUrl: summary.coverImage,
                icon: Icons.storefront_rounded,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(.82)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: _gold,
                          child: Icon(Icons.verified_rounded, color: Colors.black),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            summary.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _DarkPill('${summary.rating.toStringAsFixed(1)} ★'),
                        _DarkPill('${summary.packageCount} menus'),
                        _DarkPill('From ₹${summary.startingPrice.toStringAsFixed(0)}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => context.go('/search?q=${Uri.encodeComponent(summary.title)}'),
                      child: const Text('Book Now'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopularMenus extends StatelessWidget {
  const _PopularMenus({required this.items});

  final AsyncValue<List<MarketplaceContentItem>> items;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'Popular menus',
      subtitle: 'Regional and international favorites',
      child: items.when(
        loading: () => const _HorizontalSkeleton(height: 160),
        error: (_, __) => const _InlineError(message: 'Unable to load popular menus'),
        data: (liveItems) {
          if (liveItems.isEmpty) {
            return const _EmptyLiveData(
              icon: Icons.restaurant_menu_outlined,
              title: 'Popular menus are being configured',
              message: 'Publish popular menu entries in Supabase.',
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 900
                  ? 4
                  : constraints.maxWidth > 620
                      ? 3
                      : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: liveItems.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.45,
                ),
                itemBuilder: (context, index) {
                  final menu = liveItems[index];
                  return Card(
                    elevation: 0,
                    color: index.isEven ? _softPurple : _surfaceGold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => context.go(_routeForContent(menu)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(menu.icon, style: const TextStyle(fontSize: 30)),
                            const SizedBox(height: 10),
                            Text(menu.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _TodaysOffers extends StatelessWidget {
  const _TodaysOffers({required this.banners, required this.packages});

  final AsyncValue<List<HeroBanner>> banners;
  final AsyncValue<List<CateringPackage>> packages;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: "Today's special offers",
      subtitle: 'Live discounts and high-value platters',
      child: banners.when(
        loading: () => const _HorizontalSkeleton(height: 120),
        error: (_, __) => _offerPackages(packages.valueOrNull ?? const []),
        data: (items) {
          if (items.isEmpty) return _offerPackages(packages.valueOrNull ?? const []);
          return Column(
            children: [
              for (final banner in items.take(3))
                Card(
                  color: _surfaceGold,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: _purple,
                      child: Icon(Icons.local_offer_rounded, color: Colors.white),
                    ),
                    title: Text(banner.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text(banner.subtitle),
                    trailing: const Icon(Icons.arrow_forward_rounded),
                    onTap: () => context.go('/search?q=${Uri.encodeComponent(banner.title)}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _offerPackages(List<CateringPackage> packages) {
    final offers = packages.take(3).toList(growable: false);
    if (offers.isEmpty) {
      return const _EmptyLiveData(
        icon: Icons.local_offer_outlined,
        title: 'Offers are being refreshed',
        message: 'Pull to refresh for live festival and platter deals.',
      );
    }
    return Column(
      children: [
        for (final package in offers)
          Builder(
            builder: (context) => Card(
              color: _surfaceGold,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: _purple,
                  child: Icon(Icons.local_offer_rounded, color: Colors.white),
                ),
                title: Text(package.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text('From ₹${package.pricePerGuest.toStringAsFixed(0)} / plate'),
                trailing: const Icon(Icons.arrow_forward_rounded),
                onTap: () => context.go('/package/${package.id}'),
              ),
            ),
          ),
      ],
    );
  }
}

class _NearbyCaterers extends StatelessWidget {
  const _NearbyCaterers({required this.packages});

  final AsyncValue<List<CateringPackage>> packages;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'Nearby caterers',
      subtitle: 'Sorted by active packages available for your city',
      actionLabel: 'Change location',
      onAction: () => context.go('/addresses'),
      child: packages.when(
        loading: () => const _HorizontalSkeleton(height: 150),
        error: (_, __) => const _InlineError(message: 'Unable to load nearby caterers'),
        data: (items) {
          final visible = items.take(5).toList(growable: false);
          if (visible.isEmpty) {
            return const _EmptyLiveData(
              icon: Icons.near_me_outlined,
              title: 'No nearby packages yet',
              message: 'Choose another event location or pull to refresh.',
            );
          }
          return Column(
            children: [
              for (final package in visible)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 58,
                        height: 58,
                        child: _NetworkOrGradientImage(
                          imageUrl: package.imageUrl,
                          icon: Icons.restaurant_rounded,
                        ),
                      ),
                    ),
                    title: Text(package.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text('${package.rating.toStringAsFixed(1)} ★ • ${package.cuisine}'),
                    trailing: Text('₹${package.pricePerGuest.toStringAsFixed(0)}'),
                    onTap: () => context.go('/package/${package.id}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewsCarousel extends StatelessWidget {
  const _ReviewsCarousel({required this.reviews});

  final AsyncValue<List<CustomerReviewHighlight>> reviews;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'Customer reviews',
      subtitle: 'Live reviews from completed bookings',
      child: reviews.when(
        loading: () => const _HorizontalSkeleton(height: 156),
        error: (_, __) => const _InlineError(message: 'Unable to load reviews'),
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyLiveData(
              icon: Icons.reviews_outlined,
              title: 'Reviews will appear after completed orders',
              message: 'BookMyPlatter shows only live customer reviews.',
            );
          }
          return SizedBox(
            height: 176,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final review = items[index];
                return SizedBox(
                  width: 292,
                  child: Card(
                    color: _softPurple,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _RatingPill(rating: review.rating),
                          const SizedBox(height: 12),
                          Text(
                            review.comment,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          Text(
                            review.packageName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _WhyBookMyPlatter extends StatelessWidget {
  const _WhyBookMyPlatter({required this.items});

  final AsyncValue<List<MarketplaceContentItem>> items;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'Why BookMyPlatter',
      subtitle: 'A safer marketplace for every catered event',
      child: items.when(
        loading: () => const _HorizontalSkeleton(height: 140),
        error: (_, __) => const _InlineError(message: 'Unable to load trust signals'),
        data: (liveItems) {
          if (liveItems.isEmpty) {
            return const _EmptyLiveData(
              icon: Icons.verified_user_outlined,
              title: 'Trust content is being configured',
              message: 'Publish trust badges in Supabase marketplace content.',
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 700 ? 3 : 2;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.45,
                children: [
                  for (final item in liveItems) _TrustTile(item.icon, item.title),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TrustTile extends StatelessWidget {
  const _TrustTile(this.icon, this.title);

  final String icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: _softPurple,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _DownloadAppBanner extends StatelessWidget {
  const _DownloadAppBanner();

  @override
  Widget build(BuildContext context) {
    return _GradientBanner(
      title: 'Book faster on the app',
      subtitle: 'Track orders live, manage menus, and receive exclusive app-only reminders.',
      icon: Icons.phone_iphone_rounded,
      actionLabel: 'Manage notifications',
      onPressed: () => context.go('/notifications'),
    );
  }
}

class _ReferralBanner extends StatelessWidget {
  const _ReferralBanner();

  @override
  Widget build(BuildContext context) {
    return _GradientBanner(
      title: 'Invite friends, earn rewards',
      subtitle: 'Share BookMyPlatter and unlock loyalty benefits after successful bookings.',
      icon: Icons.card_giftcard_rounded,
      actionLabel: 'View rewards',
      onPressed: () => context.go('/rewards'),
      compact: true,
    );
  }
}

class _GradientBanner extends StatelessWidget {
  const _GradientBanner({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.actionLabel,
    required this.onPressed,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 18 : 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(colors: [_purple, Color(0xFF7435B8)]),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: compact ? 24 : 30,
            backgroundColor: _gold,
            child: Icon(icon, color: Colors.black),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonal(onPressed: onPressed, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _BlogAndTips extends StatelessWidget {
  const _BlogAndTips({required this.items});

  final AsyncValue<List<MarketplaceContentItem>> items;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'Blog & tips',
      subtitle: 'Planning guidance for stress-free hosting',
      child: items.when(
        loading: () => const _HorizontalSkeleton(height: 132),
        error: (_, __) => const _InlineError(message: 'Unable to load planning tips'),
        data: (liveItems) {
          if (liveItems.isEmpty) {
            return const _EmptyLiveData(
              icon: Icons.tips_and_updates_outlined,
              title: 'Planning tips are being configured',
              message: 'Publish planning tips in Supabase marketplace content.',
            );
          }
          return Column(
            children: [
              for (final item in liveItems)
                _TipTile(
                  icon: item.icon,
                  title: item.title,
                  subtitle: item.subtitle,
                  onTap: () => context.go(_routeForContent(item)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TipTile extends StatelessWidget {
  const _TipTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: _softPurple, child: Text(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _Faqs extends StatelessWidget {
  const _Faqs({required this.items});

  final AsyncValue<List<MarketplaceContentItem>> items;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'FAQs',
      subtitle: 'Quick answers before you book',
      child: items.when(
        loading: () => const _HorizontalSkeleton(height: 132),
        error: (_, __) => const _InlineError(message: 'Unable to load FAQs'),
        data: (liveItems) {
          if (liveItems.isEmpty) {
            return const _EmptyLiveData(
              icon: Icons.help_outline_rounded,
              title: 'FAQs are being configured',
              message: 'Publish FAQ content in Supabase marketplace content.',
            );
          }
          return Column(
            children: [
              for (final item in liveItems)
                _FaqTile(question: item.title, answer: item.subtitle),
            ],
          );
        },
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ExpansionTile(
        title: Text(question, style: const TextStyle(fontWeight: FontWeight.w900)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [Align(alignment: Alignment.centerLeft, child: Text(answer))],
      ),
    );
  }
}

class _ContactSupport extends StatelessWidget {
  const _ContactSupport();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: _surfaceGold,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(18),
        leading: const CircleAvatar(
          backgroundColor: _purple,
          child: Icon(Icons.support_agent_rounded, color: Colors.white),
        ),
        title: const Text('Need help planning?', style: TextStyle(fontWeight: FontWeight.w900)),
        subtitle: const Text('Contact support for package, payment, or order help.'),
        trailing: const Icon(Icons.arrow_forward_rounded),
        onTap: () => context.go('/support'),
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.title,
    required this.subtitle,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: _purple,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            if (actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

class _NetworkOrGradientImage extends StatelessWidget {
  const _NetworkOrGradientImage({required this.imageUrl, required this.icon});

  final String? imageUrl;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => const _ImageSkeleton(),
        errorWidget: (_, __, ___) => _GradientImage(icon: icon),
      );
    }
    return _GradientImage(icon: icon);
  }
}

class _GradientImage extends StatelessWidget {
  const _GradientImage({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_softPurple, _surfaceGold],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(child: Icon(icon, color: _purple, size: 46)),
    );
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: rating >= 4.3 ? Colors.green.shade700 : _purple,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '${rating.toStringAsFixed(1)} ★',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _VegBadge extends StatelessWidget {
  const _VegBadge({required this.isVeg});

  final bool isVeg;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.circle,
              color: isVeg ? Colors.green : Colors.red,
              size: 10,
            ),
            const SizedBox(width: 5),
            Text(
              isVeg ? 'Veg' : 'Non Veg',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkPill extends StatelessWidget {
  const _DarkPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.46),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _AnimatedIn extends StatelessWidget {
  const _AnimatedIn({required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + delay.inMilliseconds),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0, 1).toDouble(),
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade50,
      elevation: 0,
      child: ListTile(
        leading: Icon(Icons.error_outline, color: Colors.red.shade700),
        title: Text(message),
      ),
    );
  }
}

class _EmptyLiveData extends StatelessWidget {
  const _EmptyLiveData({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: _softPurple,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: Colors.white, child: Icon(icon, color: _purple)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) => const _SkeletonBox(height: 214, radius: 28);
}

class _HorizontalSkeleton extends StatelessWidget {
  const _HorizontalSkeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => SizedBox(
          width: 260,
          child: _SkeletonBox(height: height, radius: 24),
        ),
      ),
    );
  }
}

class _PackageSkeletonGrid extends StatelessWidget {
  const _PackageSkeletonGrid({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 900 ? 3 : constraints.maxWidth > 620 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: compact ? columns : columns * 2,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: columns == 1 ? 1.02 : .82,
          ),
          itemBuilder: (_, __) => const _SkeletonBox(height: 260, radius: 24),
        );
      },
    );
  }
}

class _ImageSkeleton extends StatelessWidget {
  const _ImageSkeleton();

  @override
  Widget build(BuildContext context) => const _SkeletonBox(height: double.infinity, radius: 0);
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height, required this.radius});

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .35, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, _) {
        return Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: Color.lerp(_softPurple, _surfaceGold, value),
          ),
        );
      },
    );
  }
}

class _CatererSummary {
  const _CatererSummary({
    required this.title,
    required this.coverImage,
    required this.rating,
    required this.startingPrice,
    required this.packageCount,
  });

  final String title;
  final String? coverImage;
  final double rating;
  final double startingPrice;
  final int packageCount;
}

String _routeForContent(MarketplaceContentItem item) {
  if (item.route != null && item.route!.startsWith('/')) return item.route!;
  final query = Uri.encodeComponent(
    (item.searchQuery == null || item.searchQuery!.trim().isEmpty)
        ? item.title
        : item.searchQuery!.trim(),
  );
  return '/search?q=$query';
}

bool _isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= 720;
