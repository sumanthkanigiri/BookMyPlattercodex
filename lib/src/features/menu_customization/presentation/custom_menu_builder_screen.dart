import 'package:bookmyplatter/src/features/cart/application/cart_controller.dart';
import 'package:bookmyplatter/src/features/catalog/data/catalog_repository.dart';
import 'package:bookmyplatter/src/features/menu_customization/application/menu_customization_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CustomMenuBuilderScreen extends ConsumerStatefulWidget {
  const CustomMenuBuilderScreen({required this.packageId, super.key});
  final String packageId;

  @override
  ConsumerState<CustomMenuBuilderScreen> createState() => _CustomMenuBuilderScreenState();
}

class _CustomMenuBuilderScreenState extends ConsumerState<CustomMenuBuilderScreen> {
  MenuCustomizationDraft? draft;

  @override
  Widget build(BuildContext context) {
    final package = ref.watch(packageProvider(widget.packageId));
    return Scaffold(
      appBar: AppBar(title: const Text('Customize menu')),
      body: package.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (item) {
          draft ??= MenuCustomizationDraft(
            packageId: item.id,
            guestCount: item.minGuests,
            selectedDishes: item.menuItems.take(8).toList(),
            basePricePerGuest: item.pricePerGuest,
          );
          final current = draft!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(item.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('Build a menu that matches your event. Prices update instantly as you adjust dishes and premium add-ons.'),
              const SizedBox(height: 20),
              _PriceCard(draft: current),
              const SizedBox(height: 20),
              Text('Guest count', style: Theme.of(context).textTheme.titleLarge),
              Slider(
                value: current.guestCount.toDouble(),
                min: item.minGuests.toDouble(),
                max: item.maxGuests.toDouble(),
                divisions: item.maxGuests == item.minGuests ? null : item.maxGuests - item.minGuests,
                label: '${current.guestCount}',
                onChanged: (value) => setState(() => draft = current.copyWith(guestCount: value.round())),
              ),
              Text('${current.guestCount} guests'),
              const SizedBox(height: 20),
              Text('Included dishes', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final dish in item.menuItems)
                CheckboxListTile(
                  value: current.selectedDishes.contains(dish),
                  title: Text(dish),
                  onChanged: (selected) {
                    final dishes = [...current.selectedDishes];
                    if (selected == true && !dishes.contains(dish)) dishes.add(dish);
                    if (selected == false) dishes.remove(dish);
                    setState(() => draft = current.copyWith(selectedDishes: dishes));
                  },
                ),
              const SizedBox(height: 20),
              Text('Premium upgrades', style: Theme.of(context).textTheme.titleLarge),
              _StepperTile(label: 'Live counters', value: current.liveCounters, onChanged: (value) => setState(() => draft = current.copyWith(liveCounters: value))),
              _StepperTile(label: 'Beverage stations', value: current.beverages, onChanged: (value) => setState(() => draft = current.copyWith(beverages: value))),
              _StepperTile(label: 'Decorations', value: current.decorations, onChanged: (value) => setState(() => draft = current.copyWith(decorations: value))),
              _StepperTile(label: 'Return gifts', value: current.returnGifts, onChanged: (value) => setState(() => draft = current.copyWith(returnGifts: value))),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  try {
                    await ref.read(menuCustomizationRepositoryProvider).save(current);
                    if (!context.mounted) return;
                    ref.read(cartControllerProvider.notifier).addPackage(item, guests: current.guestCount);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customized menu saved')));
                    context.go('/checkout');
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save and continue booking'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.draft});
  final MenuCustomizationDraft draft;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Live price', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('₹${draft.pricePerGuest.toStringAsFixed(0)} per guest'),
              Text('₹${draft.total.toStringAsFixed(0)} estimated total'),
              Text('${draft.selectedDishes.length} dishes selected'),
            ],
          ),
        ),
      );
}

class _StepperTile extends StatelessWidget {
  const _StepperTile({required this.label, required this.value, required this.onChanged});
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(label),
        subtitle: const Text('Adds a premium per-guest upgrade'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.filledTonal(onPressed: value == 0 ? null : () => onChanged(value - 1), icon: const Icon(Icons.remove)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('$value')),
            IconButton.filledTonal(onPressed: () => onChanged(value + 1), icon: const Icon(Icons.add)),
          ],
        ),
      );
}
