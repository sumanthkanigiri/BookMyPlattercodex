import 'package:bookmyplatter/src/features/loyalty/application/loyalty_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps loyalty activity returned by Supabase', () {
    final transaction = LoyaltyTransaction.fromMap({
      'kind': 'order_reward',
      'description': 'Points earned for completed booking',
      'points_delta': 42,
      'amount_delta': 0,
      'created_at': '2026-08-04T12:00:00Z',
    });

    expect(transaction.kind, 'order_reward');
    expect(transaction.pointsDelta, 42);
    expect(transaction.amountDelta, 0);
    expect(transaction.createdAt.isUtc, isFalse);
  });
}
