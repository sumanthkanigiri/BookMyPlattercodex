class OrderStatusEvent {
  const OrderStatusEvent({required this.status, required this.message, required this.createdAt});

  factory OrderStatusEvent.fromMap(Map<String, dynamic> map) => OrderStatusEvent(
        status: map['status'] as String,
        message: map['message'] as String,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      );

  final String status;
  final String message;
  final DateTime createdAt;
}

class PlatterOrder {
  const PlatterOrder({
    required this.id,
    required this.packageName,
    required this.guestCount,
    required this.eventAt,
    required this.deliveryAddress,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.events,
    this.packageImageUrl,
  });

  factory PlatterOrder.fromMap(Map<String, dynamic> map) {
    final package = map['packages'] as Map<String, dynamic>;
    final eventRows = (map['order_status_events'] as List<dynamic>?) ?? const [];
    return PlatterOrder(
      id: map['id'] as String,
      packageName: package['name'] as String,
      packageImageUrl: package['image_url'] as String?,
      guestCount: map['guest_count'] as int,
      eventAt: DateTime.parse(map['event_at'] as String).toLocal(),
      deliveryAddress: map['delivery_address'] as String,
      subtotal: (map['subtotal'] as num).toDouble(),
      discount: (map['discount_total'] as num).toDouble(),
      tax: (map['tax_total'] as num).toDouble(),
      total: (map['grand_total'] as num).toDouble(),
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      events: [
        for (final row in eventRows)
          OrderStatusEvent.fromMap(row as Map<String, dynamic>),
      ],
    );
  }

  final String id;
  final String packageName;
  final String? packageImageUrl;
  final int guestCount;
  final DateTime eventAt;
  final String deliveryAddress;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String status;
  final DateTime createdAt;
  final List<OrderStatusEvent> events;

  bool get isActive => !{'delivered', 'cancelled', 'refunded'}.contains(status);
}
