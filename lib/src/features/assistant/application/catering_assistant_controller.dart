import 'package:bookmyplatter/src/core/supabase/supabase_providers.dart';
import 'package:bookmyplatter/src/features/catalog/domain/package.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CateringAssistantState {
  const CateringAssistantState({
    this.eventType,
    this.foodPreference,
    this.guestCount = 50,
    this.eventDate,
    this.mealTime,
    this.addressId,
    this.manualAddress,
    this.budgetMaximum,
  });

  factory CateringAssistantState.fromMap(Map<String, dynamic> map) => CateringAssistantState(
        eventType: map['event_type'] as String?,
        foodPreference: map['food_preference'] as String?,
        guestCount: map['guest_count'] as int? ?? 50,
        eventDate: map['event_date'] == null ? null : DateTime.parse(map['event_date'] as String),
        mealTime: map['meal_time'] as String?,
        addressId: map['address_id'] as String?,
        manualAddress: map['manual_address'] as String?,
        budgetMaximum: (map['budget_maximum'] as num?)?.toDouble(),
      );

  final String? eventType;
  final String? foodPreference;
  final int guestCount;
  final DateTime? eventDate;
  final String? mealTime;
  final String? addressId;
  final String? manualAddress;
  final double? budgetMaximum;

  bool get hasProgress =>
      eventType != null ||
      foodPreference != null ||
      eventDate != null ||
      mealTime != null ||
      addressId != null ||
      (manualAddress?.trim().isNotEmpty ?? false) ||
      budgetMaximum != null;

  Map<String, dynamic> toMap() => {
        'event_type': eventType,
        'food_preference': foodPreference,
        'guest_count': guestCount,
        'event_date': eventDate?.toIso8601String(),
        'meal_time': mealTime,
        'address_id': addressId,
        'manual_address': manualAddress,
        'budget_maximum': budgetMaximum,
      };

  CateringAssistantState copyWith({
    String? eventType,
    String? foodPreference,
    int? guestCount,
    DateTime? eventDate,
    String? mealTime,
    String? addressId,
    String? manualAddress,
    double? budgetMaximum,
  }) => CateringAssistantState(
        eventType: eventType ?? this.eventType,
        foodPreference: foodPreference ?? this.foodPreference,
        guestCount: guestCount ?? this.guestCount,
        eventDate: eventDate ?? this.eventDate,
        mealTime: mealTime ?? this.mealTime,
        addressId: addressId ?? this.addressId,
        manualAddress: manualAddress ?? this.manualAddress,
        budgetMaximum: budgetMaximum ?? this.budgetMaximum,
      );
}

final cateringAssistantRepositoryProvider = Provider<CateringAssistantRepository>((ref) {
  return CateringAssistantRepository(ref.watch(supabaseClientProvider));
});

final cateringAssistantControllerProvider = StateNotifierProvider<CateringAssistantController,
    AsyncValue<CateringAssistantState>>((ref) {
  ref.watch(authenticatedUserIdProvider);
  return CateringAssistantController(ref.watch(cateringAssistantRepositoryProvider));
});

class CateringAssistantRepository {
  const CateringAssistantRepository(this._client);
  final SupabaseClient _client;

  Future<CateringAssistantState> load() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const CateringAssistantState();
    final row = await _client
        .from('booking_drafts')
        .select('answers')
        .eq('customer_id', userId)
        .maybeSingle();
    return row == null
        ? const CateringAssistantState()
        : CateringAssistantState.fromMap(row['answers'] as Map<String, dynamic>);
  }

  Future<void> save(CateringAssistantState state) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('booking_drafts').upsert({
      'customer_id': userId,
      'answers': state.toMap(),
    });
  }

  Future<List<CateringPackage>> recommend(CateringAssistantState state) async {
    final rankings = await _client.rpc<List<dynamic>>('recommend_catering_packages', params: {
      'p_event_type': state.eventType,
      'p_food_preference': state.foodPreference,
      'p_guest_count': state.guestCount,
      'p_budget_max': state.budgetMaximum,
    });
    final ids = [for (final row in rankings) (row as Map<String, dynamic>)['package_id'] as String];
    if (ids.isEmpty) return const [];
    final rows = await _client
        .from('packages')
        .select('id,vendor_id,category_id,name,description,price_per_guest,min_guests,max_guests,rating,is_veg,image_url,package_type,cuisine,event_types,popularity_score,menu_items(name,sort_order),package_images(image_url,sort_order)')
        .inFilter('id', ids);
    final packages = {for (final row in rows) row['id'] as String: CateringPackage.fromMap(row)};
    return [for (final id in ids) if (packages[id] != null) packages[id]!];
  }
}

class CateringAssistantController extends StateNotifier<AsyncValue<CateringAssistantState>> {
  CateringAssistantController(this._repository) : super(const AsyncLoading()) {
    _load();
  }
  final CateringAssistantRepository _repository;

  Future<void> _load() async => state = await AsyncValue.guard(_repository.load);

  Future<void> update(CateringAssistantState Function(CateringAssistantState) change) async {
    final current = state.valueOrNull ?? const CateringAssistantState();
    final next = change(current);
    state = AsyncData(next);
    await _repository.save(next);
  }
}

final assistantRecommendationsProvider = FutureProvider<List<CateringPackage>>((ref) async {
  final state = ref.watch(cateringAssistantControllerProvider).valueOrNull;
  if (state == null || state.eventType == null || state.foodPreference == null) return const [];
  return ref.watch(cateringAssistantRepositoryProvider).recommend(state);
});
