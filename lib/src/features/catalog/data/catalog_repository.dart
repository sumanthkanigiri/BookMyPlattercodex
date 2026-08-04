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


final marketplaceCollectionProvider =
    FutureProvider.family<List<MarketplaceContentItem>, String>((ref, key) {
  return ref.watch(catalogRepositoryProvider).marketplaceCollection(key);
});

final searchSuggestionsProvider =
    FutureProvider.family<List<SearchSuggestion>, String>((ref, query) {
  return ref.watch(catalogRepositoryProvider).searchSuggestions(query);
});

final customerReviewHighlightsProvider = FutureProvider<List<CustomerReviewHighlight>>((ref) {
  return ref.watch(catalogRepositoryProvider).customerReviewHighlights();
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


class MarketplaceContentItem {
  const MarketplaceContentItem({
    required this.id,
    required this.collectionKey,
    required this.title,
    required this.sortOrder,
    this.subtitle = '',
    this.icon = '🍽️',
    this.route,
    this.searchQuery,
    this.imageUrl,
  });

  factory MarketplaceContentItem.fromMap(Map<String, dynamic> map) {
    return MarketplaceContentItem(
      id: map['id'] as String,
      collectionKey: map['collection_key'] as String,
      title: map['title'] as String,
      subtitle: map['subtitle'] as String? ?? '',
      icon: map['icon'] as String? ?? '🍽️',
      route: map['route'] as String?,
      searchQuery: map['search_query'] as String?,
      imageUrl: map['image_url'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  final String id;
  final String collectionKey;
  final String title;
  final String subtitle;
  final String icon;
  final String? route;
  final String? searchQuery;
  final String? imageUrl;
  final int sortOrder;
}

class SearchSuggestion {
  const SearchSuggestion({required this.label, required this.route, required this.icon});

  final String label;
  final String route;
  final String icon;
}

class CustomerReviewHighlight {
  const CustomerReviewHighlight({
    required this.id,
    required this.packageName,
    required this.rating,
    required this.comment,
  });

  factory CustomerReviewHighlight.fromMap(Map<String, dynamic> map) {
    final package = map['packages'] as Map<String, dynamic>?;
    return CustomerReviewHighlight(
      id: map['id'] as String,
      packageName: package?['name'] as String? ?? 'Booked package',
      rating: (map['rating'] as num).toDouble(),
      comment: map['comment'] as String? ?? '',
    );
  }

  final String id;
  final String packageName;
  final double rating;
  final String comment;
}

class CatalogRepository {
  const CatalogRepository(this._client);

  final SupabaseClient _client;

  Future<List<Category>> categories() async {
    final rows = await _client
        .from('categories')
        .select('id,name,icon')
        .eq('is_active', true)
        .order('sort_order')
        .limit(100);
    return [for (final row in rows) Category.fromMap(row)];
  }

  Future<List<HeroBanner>> banners() async {
    final rows = await _client
        .from('banners')
        .select('title,subtitle,image_url')
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(20);
    return [for (final row in rows) HeroBanner.fromMap(row)];
  }

  Future<List<CateringPackage>> packages(PackageQuery filters) async {
    var request = _client
        .from('packages')
        .select('id,vendor_id,category_id,name,description,price_per_guest,min_guests,max_guests,rating,is_veg,image_url,package_type,cuisine,event_types,popularity_score,menu_items(name,sort_order),package_images(image_url,sort_order)')
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
      PackageSort.popularity => await request.order('popularity_score', ascending: false).limit(100),
      PackageSort.rating => await request.order('rating', ascending: false).limit(100),
      PackageSort.priceLowToHigh => await request.order('price_per_guest').limit(100),
      PackageSort.priceHighToLow => await request.order('price_per_guest', ascending: false).limit(100),
    };
    return [for (final row in rows) CateringPackage.fromMap(row)];
  }

  Future<CateringPackage> packageById(String id) async {
    final row = await _client
        .from('packages')
        .select('id,vendor_id,category_id,name,description,price_per_guest,min_guests,max_guests,rating,is_veg,image_url,package_type,cuisine,event_types,popularity_score,menu_items(name,sort_order),package_images(image_url,sort_order)')
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

  Future<List<MarketplaceContentItem>> marketplaceCollection(String key) async {
    final rows = await _client
        .from('marketplace_content_items')
        .select('id,collection_key,title,subtitle,icon,route,search_query,image_url,sort_order')
        .eq('collection_key', key)
        .eq('is_active', true)
        .order('sort_order')
        .limit(50);
    return [for (final row in rows) MarketplaceContentItem.fromMap(row)];
  }

  Future<List<SearchSuggestion>> searchSuggestions(String query) async {
    final normalized = query.trim();
    if (normalized.length < 2) return const [];
    final encoded = '%$normalized%';
    final packageRows = await _client
        .from('packages')
        .select('id,name')
        .eq('is_active', true)
        .ilike('name', encoded)
        .limit(5);
    final categoryRows = await _client
        .from('categories')
        .select('id,name,icon')
        .eq('is_active', true)
        .ilike('name', encoded)
        .limit(5);
    return [
      for (final row in packageRows)
        SearchSuggestion(
          label: row['name'] as String,
          route: '/package/${row['id']}',
          icon: '🍽️',
        ),
      for (final row in categoryRows)
        SearchSuggestion(
          label: row['name'] as String,
          route: '/search?category=${row['id']}',
          icon: row['icon'] as String? ?? '🍱',
        ),
    ];
  }

  Future<List<CustomerReviewHighlight>> customerReviewHighlights() async {
    final rows = await _client
        .from('reviews')
        .select('id,rating,comment,packages(name)')
        .not('comment', 'is', null)
        .order('created_at', ascending: false)
        .limit(12);
    return [for (final row in rows) CustomerReviewHighlight.fromMap(row)];
  }

}
