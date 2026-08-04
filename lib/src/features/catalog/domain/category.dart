class Category {
  const Category({required this.id, required this.name, required this.icon});

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: (map['icon'] as String?) ?? '🍽️',
    );
  }

  final String id;
  final String name;
  final String icon;
}
