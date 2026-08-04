import 'package:bookmyplatter_admin/src/features/operations/operations_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps kitchen orders and nested operation notes', () {
    final order = KitchenOrder.fromMap({
      'id': 'order-1',
      'customer_id': 'customer-1',
      'event_at': '2026-08-05T12:00:00Z',
      'status': 'preparing',
      'guest_count': 80,
      'delivery_address': '12 Celebration Road',
      'notes': 'No onion',
      'packages': {'name': 'Celebration Combo'},
      'profiles': {'full_name': 'Customer'},
      'order_operations': {'kitchen_notes': 'Pack sweets separately'},
    });

    expect(order.packageName, 'Celebration Combo');
    expect(order.guests, 80);
    expect(order.kitchenNotes, 'Pack sweets separately');
  });

  test('detects inventory at its reorder threshold', () {
    final item = InventoryItem.fromMap({
      'id': 'item-1',
      'name': 'Basmati rice',
      'unit': 'kg',
      'quantity': 20,
      'reorder_level': 20,
      'unit_cost': 110,
    });

    expect(item.lowStock, isTrue);
    expect(item.unitCost, 110);
  });

  test('maps delivery location and staff relationship', () {
    final delivery = DeliveryAssignment.fromMap({
      'id': 'delivery-1',
      'order_id': 'order-1',
      'status': 'en_route',
      'current_latitude': 17.385,
      'current_longitude': 78.4867,
      'estimated_arrival_at': '2026-08-05T12:00:00Z',
      'orders': {'delivery_address': 'Hyderabad'},
      'staff_members': {
        'profiles': {'full_name': 'Delivery Team'},
      },
    });

    expect(delivery.staffName, 'Delivery Team');
    expect(delivery.latitude, 17.385);
    expect(delivery.address, 'Hyderabad');
  });
}
