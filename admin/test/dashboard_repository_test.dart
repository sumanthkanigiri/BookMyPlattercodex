import 'package:bookmyplatter_admin/src/features/dashboard/dashboard_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps live order rows used by the operations dashboard', () {
    final order = AdminOrder.fromMap({
      'id': 'order-id',
      'profiles': {'full_name': 'Ananya Rao'},
      'packages': {'name': 'Celebration Platter'},
      'event_at': '2026-08-05T12:00:00Z',
      'status': 'confirmed',
      'grand_total': 12500,
    });

    expect(order.customer, 'Ananya Rao');
    expect(order.packageName, 'Celebration Platter');
    expect(order.status, 'confirmed');
    expect(order.total, 12500);
  });
}
