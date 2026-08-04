import 'package:bookmyplatter/src/core/errors/app_exception.dart';
import 'package:bookmyplatter/src/core/supabase/supabase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final menuCustomizationRepositoryProvider = Provider<MenuCustomizationRepository>((ref) {
  return MenuCustomizationRepository(ref.watch(supabaseClientProvider));
});

class MenuCustomizationDraft {
  const MenuCustomizationDraft({
    required this.packageId,
    required this.guestCount,
    required this.selectedDishes,
    required this.basePricePerGuest,
    this.liveCounters = 0,
    this.beverages = 0,
    this.decorations = 0,
    this.returnGifts = 0,
  });

  final String packageId;
  final int guestCount;
  final List<String> selectedDishes;
  final double basePricePerGuest;
  final int liveCounters;
  final int beverages;
  final int decorations;
  final int returnGifts;

  double get extrasPerGuest => (liveCounters * 60) + (beverages * 35) + (decorations * 25) + (returnGifts * 45);
  double get dishAdjustmentPerGuest => selectedDishes.length <= 6 ? 0 : (selectedDishes.length - 6) * 18;
  double get pricePerGuest => basePricePerGuest + extrasPerGuest + dishAdjustmentPerGuest;
  double get total => pricePerGuest * guestCount;

  MenuCustomizationDraft copyWith({
    int? guestCount,
    List<String>? selectedDishes,
    int? liveCounters,
    int? beverages,
    int? decorations,
    int? returnGifts,
  }) {
    return MenuCustomizationDraft(
      packageId: packageId,
      guestCount: guestCount ?? this.guestCount,
      selectedDishes: selectedDishes ?? this.selectedDishes,
      basePricePerGuest: basePricePerGuest,
      liveCounters: liveCounters ?? this.liveCounters,
      beverages: beverages ?? this.beverages,
      decorations: decorations ?? this.decorations,
      returnGifts: returnGifts ?? this.returnGifts,
    );
  }

  Map<String, dynamic> toPersistence(String customerId) => {
        'customer_id': customerId,
        'package_id': packageId,
        'guest_count': guestCount,
        'selected_menu_items': selectedDishes,
        'extras': {
          'live_counters': liveCounters,
          'beverages': beverages,
          'decorations': decorations,
          'return_gifts': returnGifts,
        },
        'price_snapshot': {
          'base_price_per_guest': basePricePerGuest,
          'extras_per_guest': extrasPerGuest,
          'dish_adjustment_per_guest': dishAdjustmentPerGuest,
          'final_price_per_guest': pricePerGuest,
          'grand_total': total,
        },
        'status': 'saved',
      };
}

class MenuCustomizationRepository {
  const MenuCustomizationRepository(this._client);
  final SupabaseClient _client;

  String get customerId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AppException('Sign in to save customized menus', code: 'auth_required');
    return id;
  }

  Future<void> save(MenuCustomizationDraft draft) async {
    if (draft.selectedDishes.isEmpty) {
      throw const AppException('Select at least one dish', code: 'menu_empty');
    }
    await _client.from('booking_menu_customizations').insert(draft.toPersistence(customerId));
  }
}
