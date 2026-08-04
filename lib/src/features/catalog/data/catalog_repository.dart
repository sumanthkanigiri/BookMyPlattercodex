import 'package:bookmyplatter/src/core/supabase/supabase_providers.dart';
import 'package:bookmyplatter/src/features/catalog/domain/category.dart';
import 'package:bookmyplatter/src/features/catalog/domain/package.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.watch(supabaseClientProvider));
});

final categoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(catalogRepositoryProvider).categories();
});

final bannersProvider = FutureProvider<List<HeroBanner>>((ref) {
  return ref.watch(catalogRepositoryProvider).banners();
});

final packagesProvider = FutureProvider.family<List<CateringPackage>, PackageQuery>((ref, query) {
  return ref.watch(catalogRepositoryProvider).packages(query);
});

final packageProvider = FutureProvider.family<CateringPackage, String>((ref, id) {
  return ref.watch(catalogRepositoryProvider).packageById(id);
});

final recentlyViewedPackagesProvider = FutureProvider<List<CateringPackage>>((ref) {
  return ref.watch(catalogRepositoryProvider).recentlyViewed();
});

class PackageQuery {
  const PackageQuery({
    this.search = '',
    this.categoryId,
    this.packageType,
    this.cuisine,
    this.eventType,
    this.minimumPrice,
    this.maximumPrice,
    this.sort = PackageSort.popularity,
  });

  final String search;
  final String? categoryId;
  final String? packageType;
  final String? cuisine;
  final String? eventType;
  final double? minimumPrice;
  final double? maximumPrice;
  final PackageSort sort;

  @override
  bool operator ==(Object other) =>
      other is PackageQuery &&
      search == other.search && categoryId == other.categoryId &&
      packageType == other.packageType && cuisine == other.cuisine &&
      eventType == other.eventType && minimumPrice == other.minimumPrice &&
      maximumPrice == other.maximumPrice && sort == other.sort;

  @override
  int get hashCode => Object.hash(
        search, categoryId, packageType, cuisine, eventType,
        minimumPrice, maximumPrice, sort,
      );
}

enum PackageSort { popularity, rating, priceLowToHigh, priceHighToLow }

class HeroBanner {
  const HeroBanner({required this.title, required this.subtitle, this.imageUrl});

  factory HeroBanner.fromMap(Map<String, dynamic> map) => HeroBanner(
        title: map['title'] as String,
        subtitle: map['subtitle'] as String,
        imageUrl: map['image_url'] as String?,
      );

  final String title;
  final String subtitle;
  final String? imageUrl;
}

class CatalogRepository {
  const CatalogRepository(this._client);

  final SupabaseClient _client;

  Future<List<Category>> categories() async {
    final rows = await _client
        .from('categories')
        .select('id,name,icon')
        .eq('is_active', true)
        .order('sort_order');
    return [for (final row in rows) Category.fromMap(row)];
  }

  Future<List<HeroBanner>> banners() async {
    final rows = await _client
        .from('banners')
        .select('title,subtitle,image_url')
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return [for (final row in rows) HeroBanner.fromMap(row)];
  }

  Future<List<CateringPackage>> packages(PackageQuery filters) async {
    var request = _client
        .from('packages')
        .select('id,vendor_id,category_id,name,description,price_per_guest,min_guests,max_guests,rating,is_veg,image_url,package_type,cuisine,event_types,popularity_score,menu_items(name,sort_order)')
        .eq('is_active', true);
    if (filters.categoryId != null && filters.categoryId!.isNotEmpty) {
      request = request.eq('category_id', filters.categoryId!);
    }
    if (filters.search.trim().isNotEmpty) {
      request = request.textSearch(
        'search_vector',
        filters.search.trim(),
        type: TextSearchType.websearch,
      );
    }
    if (filters.packageType != null) request = request.eq('package_type', filters.packageType!);
    if (filters.cuisine != null) request = request.eq('cuisine', filters.cuisine!);
    if (filters.eventType != null) request = request.contains('event_types', [filters.eventType]);
    if (filters.minimumPrice != null) request = request.gte('price_per_guest', filters.minimumPrice!);
    if (filters.maximumPrice != null) request = request.lte('price_per_guest', filters.maximumPrice!);
    final rows = switch (filters.sort) {
      PackageSort.popularity => await request.order('popularity_score', ascending: false),
      PackageSort.rating => await request.order('rating', ascending: false),
      PackageSort.priceLowToHigh => await request.order('price_per_guest'),
      PackageSort.priceHighToLow => await request.order('price_per_guest', ascending: false),
    };
    return [for (final row in rows) CateringPackage.fromMap(row)];
  }

  Future<CateringPackage> packageById(String id) async {
    final row = await _client
        .from('packages')
        .select('id,vendor_id,category_id,name,description,price_per_guest,min_guests,max_guests,rating,is_veg,image_url,package_type,cuisine,event_types,popularity_score,menu_items(name,sort_order)')
        .eq('id', id)
        .single();
    await _client.rpc<void>('record_package_view', params: {'p_package_id': id});
    return CateringPackage.fromMap(row);
  }

  Future<List<CateringPackage>> recentlyViewed() async {
    final customerId = _client.auth.currentUser?.id;
    if (customerId == null) return const [];
    final rows = await _client
        .from('package_views')
        .select('packages(id,vendor_id,category_id,name,description,price_per_guest,min_guests,max_guests,rating,is_veg,image_url,package_type,cuisine,event_types,popularity_score)')
        .eq('customer_id', customerId)
        .order('viewed_at', ascending: false)
        .limit(10);
    return [
      for (final row in rows)
        CateringPackage.fromMap(row['packages'] as Map<String, dynamic>),
    ];
  }
}
