import 'dart:async';

import 'package:bookmyplatter/src/features/catalog/data/catalog_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final cuisineController = TextEditingController();
  Timer? debounce;
  String query = '';
  String? packageType;
  String? eventType;
  RangeValues priceRange = const RangeValues(0, 5000);
  PackageSort sort = PackageSort.popularity;

  @override
  void dispose() {
    debounce?.cancel();
    cuisineController.dispose();
    super.dispose();
  }

  PackageQuery get filters => PackageQuery(
        search: query,
        packageType: packageType,
        cuisine: cuisineController.text.trim().isEmpty ? null : cuisineController.text.trim(),
        eventType: eventType,
        minimumPrice: priceRange.start == 0 ? null : priceRange.start,
        maximumPrice: priceRange.end == 5000 ? null : priceRange.end,
        sort: sort,
      );

  void updateSearch(String value) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => query = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final packages = ref.watch(packagesProvider(filters));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a package'),
        actions: [
          IconButton(
            tooltip: 'Filters',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => _FiltersSheet(
                packageType: packageType,
                eventType: eventType,
                priceRange: priceRange,
                cuisineController: cuisineController,
                onApply: (type, event, prices) {
                  setState(() {
                    packageType = type;
                    eventType = event;
                    priceRange = prices;
                  });
                  Navigator.pop(context);
                },
                onClear: () {
                  cuisineController.clear();
                  setState(() {
                    packageType = null;
                    eventType = null;
                    priceRange = const RangeValues(0, 5000);
                  });
                  Navigator.pop(context);
                },
              ),
            ),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchBar(
              hintText: 'Search packages, dishes, or cuisine',
              leading: const Icon(Icons.search),
              onChanged: updateSearch,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Sort by', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<PackageSort>(
                    value: sort,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: PackageSort.popularity, child: Text('Popularity')),
                      DropdownMenuItem(value: PackageSort.rating, child: Text('Rating')),
                      DropdownMenuItem(value: PackageSort.priceLowToHigh, child: Text('Price: low to high')),
                      DropdownMenuItem(value: PackageSort.priceHighToLow, child: Text('Price: high to low')),
                    ],
                    onChanged: (value) => setState(() => sort = value ?? PackageSort.popularity),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: packages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Unable to load packages'),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => ref.invalidate(packagesProvider(filters)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('No packages match these filters'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final package = items[index];
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(10),
                            leading: package.imageUrl == null
                                ? const SizedBox.square(dimension: 72, child: Icon(Icons.restaurant))
                                : CachedNetworkImage(
                                    imageUrl: package.imageUrl!,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                  ),
                            title: Text(package.name),
                            subtitle: Text(
                              '${package.cuisine} • ${package.rating.toStringAsFixed(1)}★\n₹${package.pricePerGuest.toStringAsFixed(0)} per guest',
                            ),
                            isThreeLine: true,
                            onTap: () => context.go('/package/${package.id}'),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({
    required this.packageType,
    required this.eventType,
    required this.priceRange,
    required this.cuisineController,
    required this.onApply,
    required this.onClear,
  });

  final String? packageType;
  final String? eventType;
  final RangeValues priceRange;
  final TextEditingController cuisineController;
  final void Function(String?, String?, RangeValues) onApply;
  final VoidCallback onClear;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late String? packageType = widget.packageType;
  late String? eventType = widget.eventType;
  late RangeValues priceRange = widget.priceRange;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filters', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 20),
                Text('Package type', style: Theme.of(context).textTheme.titleMedium),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(label: const Text('Veg'), selected: packageType == 'veg', onSelected: (_) => setState(() => packageType = 'veg')),
                    ChoiceChip(label: const Text('Non-Veg'), selected: packageType == 'non_veg', onSelected: (_) => setState(() => packageType = 'non_veg')),
                    ChoiceChip(label: const Text('Platter Box'), selected: packageType == 'platter_box', onSelected: (_) => setState(() => packageType = 'platter_box')),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: widget.cuisineController,
                  decoration: const InputDecoration(labelText: 'Cuisine', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: eventType,
                  decoration: const InputDecoration(labelText: 'Event type'),
                  items: const [
                    DropdownMenuItem(value: 'birthday', child: Text('Birthday')),
                    DropdownMenuItem(value: 'wedding', child: Text('Wedding')),
                    DropdownMenuItem(value: 'house_warming', child: Text('House warming')),
                    DropdownMenuItem(value: 'corporate', child: Text('Corporate event')),
                    DropdownMenuItem(value: 'naming_ceremony', child: Text('Naming ceremony')),
                    DropdownMenuItem(value: 'engagement', child: Text('Engagement')),
                    DropdownMenuItem(value: 'anniversary', child: Text('Anniversary')),
                    DropdownMenuItem(value: 'baby_shower', child: Text('Baby shower')),
                  ],
                  onChanged: (value) => setState(() => eventType = value),
                ),
                const SizedBox(height: 16),
                Text('₹${priceRange.start.round()} – ₹${priceRange.end.round()} per guest'),
                RangeSlider(
                  values: priceRange,
                  max: 5000,
                  divisions: 50,
                  labels: RangeLabels('₹${priceRange.start.round()}', '₹${priceRange.end.round()}'),
                  onChanged: (value) => setState(() => priceRange = value),
                ),
                Row(
                  children: [
                    TextButton(onPressed: widget.onClear, child: const Text('Clear all')),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => widget.onApply(packageType, eventType, priceRange),
                      child: const Text('Apply filters'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
