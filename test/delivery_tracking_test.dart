import 'package:bookmyplatter/src/features/orders/application/order_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps customer-safe live delivery tracking data', () {
    final tracking = CustomerDeliveryTracking.fromMap({
      'status': 'en_route',
      'current_latitude': 17.385,
      'current_longitude': 78.4867,
      'estimated_arrival_at': '2026-08-05T12:00:00Z',
      'delivered_at': null,
    });

    expect(tracking.status, 'en_route');
    expect(tracking.latitude, 17.385);
    expect(tracking.longitude, 78.4867);
    expect(tracking.estimatedArrival, isNotNull);
    expect(tracking.deliveredAt, isNull);
  });
}
