import 'package:bookmyplatter/src/features/catalog/data/catalog_repository.dart';
import 'package:bookmyplatter/src/features/catalog/domain/package.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('package filters have stable value equality for Riverpod caching', () {
    const first = PackageQuery(
      search: 'biryani',
      packageType: 'non_veg',
      eventType: 'wedding',
      maximumPrice: 1200,
      sort: PackageSort.rating,
    );
    const second = PackageQuery(
      search: 'biryani',
      packageType: 'non_veg',
      eventType: 'wedding',
      maximumPrice: 1200,
      sort: PackageSort.rating,
    );

    expect(first, second);
    expect(first.hashCode, second.hashCode);
  });

  test('maps package discovery metadata from Supabase', () {
    final package = CateringPackage.fromMap({
      'id': 'package-id',
      'vendor_id': 'business-id',
      'category_id': 'category-id',
      'name': 'Celebration Box',
      'description': 'A compact celebration platter',
      'price_per_guest': 450,
      'min_guests': 5,
      'max_guests': 25,
      'rating': 4.8,
      'is_veg': true,
      'package_type': 'platter_box',
      'cuisine': 'Indian',
      'event_types': ['birthday', 'anniversary'],
      'popularity_score': 42,
      'image_url': null,
      'menu_items': [],
      'package_images': [
        {'image_url': 'https://example.com/second.webp', 'sort_order': 2},
        {'image_url': 'https://example.com/first.webp', 'sort_order': 1},
      ],
    });

    expect(package.packageType, 'platter_box');
    expect(package.cuisine, 'Indian');
    expect(package.eventTypes, contains('anniversary'));
    expect(package.popularityScore, 42);
    expect(package.imageUrls.first, 'https://example.com/first.webp');
  });
}
