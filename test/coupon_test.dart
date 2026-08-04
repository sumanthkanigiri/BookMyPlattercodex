import 'package:bookmyplatter/src/features/coupons/domain/coupon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('applies discount only when subtotal meets minimum', () {
    const coupon = Coupon(code: 'BMP15', minimumSubtotal: 5000, discountPercent: 15);

    expect(coupon.discountFor(4000), 0);
    expect(coupon.discountFor(6000), 900);
  });

  test('uses the validated fixed discount returned by the backend', () {
    final coupon = Coupon.fromValidation(
      code: 'save500',
      data: {'couponId': 'coupon-id', 'discount': 500},
    );

    expect(coupon.id, 'coupon-id');
    expect(coupon.code, 'SAVE500');
    expect(coupon.discountFor(2000), 500);
    expect(coupon.discountFor(200), 200);
  });
}
