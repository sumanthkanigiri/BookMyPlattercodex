import 'package:bookmyplatter/src/features/catalog/data/catalog_repository.dart';
import 'package:bookmyplatter/src/features/favorites/application/favorites_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final banners = ref.watch(bannersProvider);
    final packages = ref.watch(packagesProvider(const PackageQuery()));
    final recentlyViewed = ref.watch(recentlyViewedPackagesProvider);
    final favoritesState = ref.watch(favoritesControllerProvider);
    final favorites = favoritesState.valueOrNull ?? const <String>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('BookMyPlatter'),
        actions: [
          IconButton(
            onPressed: () => context.go('/profile'),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(categoriesProvider);
          ref.invalidate(bannersProvider);
          ref.invalidate(packagesProvider);
          ref.invalidate(recentlyViewedPackagesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Find catering packages near you',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.go('/assistant'),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Plan with Catering Assistant'),
            ),
            const SizedBox(height: 12),
            SearchBar(
              hintText: 'Search menu, category, city',
              onTap: () => context.go('/search'),
            ),
            const SizedBox(height: 16),
            categories.when(
              data: (items) => SizedBox(
                height: 86,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final category = items[index];
                    return ActionChip(
                      avatar: Text(category.icon),
                      label: Text(category.name),
                      onPressed: () => context.go('/search?category=${category.id}'),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: items.length,
                ),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(error.toString()),
            ),
            banners.when(
              data: (items) => SizedBox(
                height: 170,
                child: PageView.builder(
                  controller: PageController(viewportFraction: .94),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final banner = items[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (banner.imageUrl != null)
                            CachedNetworkImage(imageUrl: banner.imageUrl!, fit: BoxFit.cover),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.black.withOpacity(.72), Colors.transparent],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(banner.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                                Text(banner.subtitle, style: const TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (error, _) => Text(error.toString()),
            ),
            const SizedBox(height: 8),
            Text('Popular packages', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            packages.when(
              data: (items) => Column(
                children: [
                  for (final item in items)
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => context.go('/package/${item.id}'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.imageUrl != null)
                              Hero(
                                tag: 'package-${item.id}',
                                child: CachedNetworkImage(
                                  imageUrl: item.imageUrl!,
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ListTile(
                              title: Text(item.name),
                              subtitle: Text('₹${item.pricePerGuest.toStringAsFixed(0)} / guest • ${item.rating.toStringAsFixed(1)} ★'),
                              trailing: IconButton(
                                icon: Icon(favorites.contains(item.id) ? Icons.favorite : Icons.favorite_border),
                                onPressed: () async {
                                  try {
                                    await ref.read(favoritesControllerProvider.notifier).toggle(item.id);
                                  } catch (_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Sign in to save favorites')),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text(error.toString()),
            ),
            recentlyViewed.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (items) => items.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Text('Recently viewed', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 130,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return SizedBox(
                                width: 220,
                                child: Card(
                                  child: ListTile(
                                    title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                                    subtitle: Text('₹${item.pricePerGuest.toStringAsFixed(0)} / guest'),
                                    onTap: () => context.go('/package/${item.id}'),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.shopping_cart), label: 'Cart'),
        ],
        onDestinationSelected: (index) {
          if (index == 1) context.go('/orders');
          if (index == 2) context.go('/cart');
        },
      ),
    );
  }
}
