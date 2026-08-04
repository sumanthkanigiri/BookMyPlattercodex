import 'package:bookmyplatter/src/features/orders/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps an active order and its tracking events', () {
    final order = PlatterOrder.fromMap({
      'id': 'order-id',
      'guest_count': 50,
      'event_at': '2026-09-10T12:00:00.000Z',
      'delivery_address': 'Central Area, Hyderabad',
      'subtotal': 10000,
      'discount_total': 500,
      'tax_total': 475,
      'grand_total': 9975,
      'status': 'confirmed',
      'created_at': '2026-08-04T10:00:00.000Z',
      'packages': {'name': 'Wedding Feast', 'image_url': null},
      'order_status_events': [
        {
          'status': 'confirmed',
          'message': 'Vendor confirmed the order',
          'created_at': '2026-08-04T10:10:00.000Z',
        },
      ],
    });

    expect(order.packageName, 'Wedding Feast');
    expect(order.total, 9975);
    expect(order.isActive, isTrue);
    expect(order.events.single.status, 'confirmed');
  });
}
