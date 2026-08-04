import 'package:bookmyplatter/src/features/checkout/application/checkout_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps admin-managed checkout controls', () {
    final settings = CheckoutSettings.fromMap({
      'cod_enabled': true,
      'tax_percent': 5,
      'delivery_charge': 149,
      'minimum_lead_hours': 36,
    });

    expect(settings.codEnabled, isTrue);
    expect(settings.taxPercent, 5);
    expect(settings.deliveryCharge, 149);
    expect(settings.minimumLeadHours, 36);
  });
}
