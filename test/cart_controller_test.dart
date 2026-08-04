import 'package:bookmyplatter/src/features/cart/application/cart_controller.dart';
import 'package:bookmyplatter/src/features/catalog/domain/package.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adds package with minimum guests and calculates subtotal', () {
    const package = CateringPackage(
      id: 'test-package',
      vendorId: 'test-vendor',
      categoryId: 'test',
      name: 'Test Package',
      description: 'Test catering package',
      pricePerGuest: 200,
      minGuests: 10,
      maxGuests: 100,
      rating: 4.5,
      menuItems: ['Rice'],
      isVeg: true,
      packageType: 'veg',
      cuisine: 'Indian',
      eventTypes: ['wedding'],
      popularityScore: 10,
    );

    final controller = CartController()..addPackage(package);

    expect(controller.items.single.guests, 10);
    expect(controller.items.single.subtotal, 2000);

    controller.updateGuests(package.id, 25);
    expect(controller.items.single.guests, 25);
    expect(controller.items.single.subtotal, 5000);

    controller.updateGuests(package.id, 1000);
    expect(controller.items.single.guests, 100);
  });
}
