class CateringPackage {
  const CateringPackage({
    required this.id,
    required this.vendorId,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.pricePerGuest,
    required this.minGuests,
    required this.maxGuests,
    required this.rating,
    required this.menuItems,
    required this.isVeg,
    required this.packageType,
    required this.cuisine,
    required this.eventTypes,
    required this.popularityScore,
    this.imageUrl,
    this.imageUrls = const [],
  });

  factory CateringPackage.fromMap(Map<String, dynamic> map) {
    final menuRows = (map['menu_items'] as List<dynamic>?) ?? const [];
    final imageRows = List<Map<String, dynamic>>.from(
      (map['package_images'] as List<dynamic>?) ?? const [],
    )..sort((left, right) => ((left['sort_order'] as int?) ?? 0).compareTo((right['sort_order'] as int?) ?? 0));
    return CateringPackage(
      id: map['id'] as String,
      vendorId: map['vendor_id'] as String,
      categoryId: map['category_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      pricePerGuest: (map['price_per_guest'] as num).toDouble(),
      minGuests: map['min_guests'] as int,
      maxGuests: map['max_guests'] as int,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      menuItems: [
        for (final row in menuRows) (row as Map<String, dynamic>)['name'] as String,
      ],
      isVeg: map['is_veg'] as bool,
      packageType: map['package_type'] as String? ?? ((map['is_veg'] as bool) ? 'veg' : 'non_veg'),
      cuisine: map['cuisine'] as String? ?? '',
      eventTypes: List<String>.from((map['event_types'] as List<dynamic>?) ?? const []),
      popularityScore: map['popularity_score'] as int? ?? 0,
      imageUrl: map['image_url'] as String?,
      imageUrls: [
        for (final row in imageRows) row['image_url'] as String,
      ],
    );
  }

  final String id;
  final String vendorId;
  final String categoryId;
  final String name;
  final String description;
  final double pricePerGuest;
  final int minGuests;
  final int maxGuests;
  final double rating;
  final List<String> menuItems;
  final bool isVeg;
  final String packageType;
  final String cuisine;
  final List<String> eventTypes;
  final int popularityScore;
  final String? imageUrl;
  final List<String> imageUrls;
}
