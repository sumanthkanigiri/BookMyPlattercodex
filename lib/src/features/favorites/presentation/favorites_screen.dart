import 'package:bookmyplatter/src/features/cart/application/cart_controller.dart';
import 'package:bookmyplatter/src/features/catalog/data/catalog_repository.dart';
import 'package:bookmyplatter/src/features/catalog/domain/package.dart';
import 'package:bookmyplatter/src/features/favorites/application/favorites_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesControllerProvider);
    final packages = ref.watch(packagesProvider(const PackageQuery()));

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(favoritesControllerProvider.notifier).refresh();
          ref.invalidate(packagesProvider);
          await ref.read(packagesProvider(const PackageQuery()).future);
        },
        child: favorites.when(
          loading: () => const _FavoritesSkeleton(),
          error: (error, _) => _FavoritesStateMessage(
            icon: Icons.favorite_border_rounded,
            title: 'Sign in to view favorites',
            message: error.toString(),
            actionLabel: 'Go to profile',
            onAction: () => context.go('/profile'),
          ),
          data: (favoriteIds) {
            if (favoriteIds.isEmpty) {
              return _FavoritesStateMessage(
                icon: Icons.favorite_border_rounded,
                title: 'No favorite packages yet',
                message: 'Tap the heart on packages you love and they will '
                    'appear here.',
                actionLabel: 'Explore packages',
                onAction: () => context.go('/search'),
              );
            }
            return packages.when(
              loading: () => const _FavoritesSkeleton(),
              error: (error, _) => _FavoritesStateMessage(
                icon: Icons.error_outline_rounded,
                title: 'Unable to load favorite packages',
                message: error.toString(),
                actionLabel: 'Try again',
                onAction: () => ref.invalidate(packagesProvider),
              ),
              data: (items) {
                final visible = items
                    .where((package) => favoriteIds.contains(package.id))
                    .toList(growable: false);
                if (visible.isEmpty) {
                  return _FavoritesStateMessage(
                    icon: Icons.sync_problem_rounded,
                    title: 'Favorite packages are unavailable',
                    message: 'Some saved packages may be inactive. Pull to '
                        'refresh after caterers update availability.',
                    actionLabel: 'Search packages',
                    onAction: () => context.go('/search'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final package = visible[index];
                    return _FavoritePackageCard(package: package);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _FavoritePackageCard extends ConsumerWidget {
  const _FavoritePackageCard({required this.package});

  final CateringPackage package;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/package/${package.id}'),
        child: Row(
          children: [
            SizedBox(
              width: 116,
              height: 116,
              child: package.imageUrl == null
                  ? const ColoredBox(
                      color: Color(0xFFF3EDFF),
                      child: Icon(Icons.restaurant_menu_rounded),
                    )
                  : CachedNetworkImage(
                      imageUrl: package.imageUrl!,
                      fit: BoxFit.cover,
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '₹${package.pricePerGuest.toStringAsFixed(0)} / plate • '
                      '${package.rating.toStringAsFixed(1)} ★',
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.tonal(
                          onPressed: () {
                            ref
                                .read(cartControllerProvider.notifier)
                                .addPackage(package);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${package.name} added to cart'),
                              ),
                            );
                          },
                          child: const Text('Add to cart'),
                        ),
                        IconButton.outlined(
                          tooltip: 'Remove favorite',
                          onPressed: () => ref
                              .read(favoritesControllerProvider.notifier)
                              .toggle(package.id),
                          icon: const Icon(Icons.favorite_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesSkeleton extends StatelessWidget {
  const _FavoritesSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Card(
        child: SizedBox(
          height: 116,
          child: Row(
            children: [
              Container(
                width: 116,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoritesStateMessage extends StatelessWidget {
  const _FavoritesStateMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 72),
        Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        FilledButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}
