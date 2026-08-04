class Address {
  const Address({
    required this.id,
    required this.label,
    required this.line1,
    required this.areaId,
    required this.area,
    required this.city,
    required this.pincode,
    this.line2,
    this.isDefault = false,
  });

  factory Address.fromMap(Map<String, dynamic> map) {
    final area = map['areas'] as Map<String, dynamic>;
    final city = area['cities'] as Map<String, dynamic>;
    return Address(
      id: map['id'] as String,
      label: map['label'] as String,
      line1: map['line1'] as String,
      line2: map['line2'] as String?,
      areaId: map['area_id'] as String,
      area: area['name'] as String,
      city: city['name'] as String,
      pincode: area['pincode'] as String? ?? '',
      isDefault: map['is_default'] as bool? ?? false,
    );
  }

  final String id;
  final String label;
  final String line1;
  final String? line2;
  final String areaId;
  final String area;
  final String city;
  final String pincode;
  final bool isDefault;
}
