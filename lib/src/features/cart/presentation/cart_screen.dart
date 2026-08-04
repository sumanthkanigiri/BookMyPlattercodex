import 'package:bookmyplatter/src/features/cart/application/cart_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartControllerProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (items.isEmpty)
              const Expanded(child: Center(child: Text('Your cart is empty')))
            else
              Expanded(
                child: ListView(
                  children: [
                    for (final item in items)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(item.package.name),
                                subtitle: Text('₹${item.package.pricePerGuest.toStringAsFixed(0)} per guest'),
                                trailing: IconButton(
                                  tooltip: 'Remove package',
                                  onPressed: () => ref.read(cartControllerProvider.notifier).removePackage(item.package.id),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton.filledTonal(
                                    onPressed: item.guests > item.package.minGuests
                                        ? () => ref.read(cartControllerProvider.notifier).updateGuests(item.package.id, item.guests - 1)
                                        : null,
                                    icon: const Icon(Icons.remove),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text('${item.guests} guests'),
                                  ),
                                  IconButton.filledTonal(
                                    onPressed: item.guests < item.package.maxGuests
                                        ? () => ref.read(cartControllerProvider.notifier).updateGuests(item.package.id, item.guests + 1)
                                        : null,
                                    icon: const Icon(Icons.add),
                                  ),
                                  const Spacer(),
                                  Text('₹${item.subtotal.toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleMedium),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal'),
                Text('₹${subtotal.toStringAsFixed(0)}'),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: items.isEmpty ? null : () => context.go('/checkout'),
              child: const Text('Proceed to checkout'),
            ),
          ],
        ),
      ),
    );
  }
}
