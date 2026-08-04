import 'package:bookmyplatter/src/features/cart/application/cart_controller.dart';
import 'package:bookmyplatter/src/features/catalog/data/catalog_repository.dart';
import 'package:bookmyplatter/src/features/favorites/application/favorites_controller.dart';
import 'package:bookmyplatter/src/features/reviews/application/review_controller.dart';
import 'package:bookmyplatter/src/features/tracking/application/customer_activity_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PackageDetailsScreen extends ConsumerStatefulWidget {
  const PackageDetailsScreen({required this.packageId, super.key});

  final String packageId;

  @override
  ConsumerState<PackageDetailsScreen> createState() => _PackageDetailsScreenState();
}

class _PackageDetailsScreenState extends ConsumerState<PackageDetailsScreen> {
  int? _guests;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(customerActivityRepositoryProvider).packageViewed(widget.packageId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final package = ref.watch(packageProvider(widget.packageId));
    final favorites = ref.watch(favoritesControllerProvider).valueOrNull ?? const <String>{};
    final reviews = ref.watch(packageReviewsProvider(widget.packageId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Package details'),
        actions: [
          IconButton(
            tooltip: favorites.contains(widget.packageId) ? 'Remove from favorites' : 'Add to favorites',
            onPressed: () async {
              try {
                await ref.read(favoritesControllerProvider.notifier).toggle(widget.packageId);
                await ref.read(customerActivityRepositoryProvider).favourite(widget.packageId);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sign in to save favorites')),
                  );
                }
              }
            },
            icon: Icon(
              favorites.contains(widget.packageId) ? Icons.favorite : Icons.favorite_border,
            ),
          ),
        ],
      ),
      body: package.when(
        data: (item) {
          final guests = (_guests ?? item.minGuests).clamp(item.minGuests, item.maxGuests).toInt();
          final total = guests * item.pricePerGuest;
          return ListView(
            children: [
              if (item.imageUrls.isNotEmpty || item.imageUrl != null)
                SizedBox(
                  height: 240,
                  child: PageView(
                    children: [
                      for (final image in item.imageUrls.isEmpty ? [item.imageUrl!] : item.imageUrls)
                        CachedNetworkImage(
                          imageUrl: image,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const _PackageImageFallback(),
                        ),
                    ],
                  ),
                )
              else
                const _PackageImageFallback(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(item.name, style: Theme.of(context).textTheme.headlineSmall)),
                        Chip(avatar: const Icon(Icons.star, size: 16), label: Text(item.rating.toStringAsFixed(1))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(item.description),
                    const SizedBox(height: 20),
                    Text('Guest count', style: Theme.of(context).textTheme.titleMedium),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: guests > item.minGuests ? () => setState(() => _guests = guests - 1) : null,
                          icon: const Icon(Icons.remove),
                        ),
                        Expanded(
                          child: Slider(
                            value: guests.toDouble(),
                            min: item.minGuests.toDouble(),
                            max: item.maxGuests.toDouble(),
                            divisions: item.maxGuests == item.minGuests ? null : item.maxGuests - item.minGuests,
                            label: '$guests',
                            onChanged: item.maxGuests == item.minGuests
                                ? null
                                : (value) => setState(() => _guests = value.round()),
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: guests < item.maxGuests ? () => setState(() => _guests = guests + 1) : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    Text('$guests guests • ₹${item.pricePerGuest.toStringAsFixed(0)} per guest'),
                    const SizedBox(height: 20),
                    Text('Included menu', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    for (final menuItem in item.menuItems)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                        title: Text(menuItem),
                      ),
                    const SizedBox(height: 20),
                    Text('Customer reviews', style: Theme.of(context).textTheme.titleLarge),
                    reviews.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Reviews are unavailable'),
                        trailing: IconButton(
                          onPressed: () => ref.invalidate(packageReviewsProvider(widget.packageId)),
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                      data: (items) => items.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('No reviews yet'),
                            )
                          : Column(
                              children: [
                                for (final review in items.take(5))
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(child: Text('${review.rating}★')),
                                    title: Text(review.comment.isEmpty ? 'Rated ${review.rating} out of 5' : review.comment),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          ref.read(cartControllerProvider.notifier).addPackage(item, guests: guests);
                          ref.read(customerActivityRepositoryProvider).cartAdded(item.id, guests: guests);
                          context.go('/cart');
                        },
                        icon: const Icon(Icons.add_shopping_cart),
                        label: Text('Add to cart • ₹${total.toStringAsFixed(0)}'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }
}

class _PackageImageFallback extends StatelessWidget {
  const _PackageImageFallback();

  @override
  Widget build(BuildContext context) => Container(
        height: 220,
        color: Theme.of(context).colorScheme.secondaryContainer,
        alignment: Alignment.center,
        child: const Icon(Icons.restaurant_menu, size: 72),
      );
}
