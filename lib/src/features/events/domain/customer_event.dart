class CustomerEvent {
  const CustomerEvent({
    required this.id,
    required this.name,
    required this.type,
    required this.eventAt,
    required this.venueName,
    required this.guestCount,
    required this.specialInstructions,
    this.addressId,
  });

  factory CustomerEvent.fromMap(Map<String, dynamic> map) => CustomerEvent(
        id: map['id'] as String,
        name: map['event_name'] as String,
        type: map['event_type'] as String,
        eventAt: DateTime.parse(map['event_at'] as String).toLocal(),
        venueName: map['venue_name'] as String? ?? '',
        addressId: map['address_id'] as String?,
        guestCount: (map['guest_count'] as num?)?.toInt() ?? 1,
        specialInstructions: map['special_instructions'] as String? ?? '',
      );

  final String id;
  final String name;
  final String type;
  final DateTime eventAt;
  final String venueName;
  final String? addressId;
  final int guestCount;
  final String specialInstructions;

  Map<String, dynamic> toMap(String customerId) => {
        'customer_id': customerId,
        'event_name': name.trim(),
        'event_type': type,
        'event_at': eventAt.toUtc().toIso8601String(),
        'venue_name': venueName.trim(),
        'address_id': addressId,
        'guest_count': guestCount,
        'special_instructions': specialInstructions.trim(),
      };
}
