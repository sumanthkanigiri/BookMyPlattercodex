import 'package:bookmyplatter/src/features/catalog/domain/package.dart';

class CartItem {
  const CartItem({required this.package, required this.guests});
  final CateringPackage package;
  final int guests;

  double get subtotal => package.pricePerGuest * guests;

  CartItem copyWith({CateringPackage? package, int? guests}) {
    return CartItem(package: package ?? this.package, guests: guests ?? this.guests);
  }
}
