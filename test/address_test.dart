import 'package:bookmyplatter/src/features/address/domain/address.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps a saved Supabase address with its area and city', () {
    final address = Address.fromMap({
      'id': 'address-id',
      'label': 'Home',
      'line1': '42 Market Road',
      'line2': 'Second floor',
      'area_id': 'area-id',
      'is_default': true,
      'areas': {
        'name': 'Central Area',
        'pincode': '500001',
        'cities': {'name': 'Hyderabad'},
      },
    });

    expect(address.areaId, 'area-id');
    expect(address.area, 'Central Area');
    expect(address.city, 'Hyderabad');
    expect(address.pincode, '500001');
    expect(address.isDefault, isTrue);
  });
}
