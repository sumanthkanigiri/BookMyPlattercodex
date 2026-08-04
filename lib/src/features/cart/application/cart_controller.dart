import 'package:bookmyplatter/src/features/cart/domain/cart_item.dart';
import 'package:bookmyplatter/src/features/catalog/domain/package.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final cartControllerProvider = StateNotifierProvider<CartController, List<CartItem>>((ref) {
  return CartController();
});

final cartSubtotalProvider = Provider<double>((ref) {
  return ref.watch(cartControllerProvider).fold<double>(0, (sum, item) => sum + item.subtotal);
});

class CartController extends StateNotifier<List<CartItem>> {
  CartController() : super(const []);

  List<CartItem> get items => state;

  void addPackage(CateringPackage package, {int? guests}) {
    final resolvedGuests = guests ?? package.minGuests;
    final index = state.indexWhere((item) => item.package.id == package.id);
    if (index == -1) {
      state = [...state, CartItem(package: package, guests: resolvedGuests)];
      return;
    }
    state = [
      for (final item in state)
        if (item.package.id == package.id) item.copyWith(guests: resolvedGuests) else item,
    ];
  }

  void removePackage(String packageId) {
    state = state.where((item) => item.package.id != packageId).toList(growable: false);
  }

  void updateGuests(String packageId, int guests) {
    state = [
      for (final item in state)
        if (item.package.id == packageId)
          item.copyWith(guests: guests.clamp(item.package.minGuests, item.package.maxGuests).toInt())
        else
          item,
    ];
  }

  void clear() => state = const [];
}
