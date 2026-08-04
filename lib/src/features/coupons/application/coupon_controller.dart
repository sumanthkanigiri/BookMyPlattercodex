import 'package:bookmyplatter/src/core/errors/app_exception.dart';
import 'package:bookmyplatter/src/core/supabase/supabase_providers.dart';
import 'package:bookmyplatter/src/features/coupons/domain/coupon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final couponRepositoryProvider = Provider<CouponRepository>((ref) {
  return CouponRepository(ref.watch(supabaseClientProvider));
});

final couponControllerProvider =
    StateNotifierProvider<CouponController, AsyncValue<Coupon?>>((ref) {
  return CouponController(ref.watch(couponRepositoryProvider));
});

class CouponRepository {
  const CouponRepository(this._client);

  final SupabaseClient _client;

  Future<Coupon> validate(String code, double subtotal) async {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      throw const AppException('Enter a coupon code', code: 'coupon_empty');
    }
    if (subtotal <= 0) {
      throw const AppException('Cart is empty', code: 'cart_empty');
    }

    final response = await _client.functions.invoke(
      'validate-coupon',
      body: {'code': normalizedCode, 'subtotal': subtotal},
    );
    final data = response.data;
    if (data is! Map<String, dynamic> || data['valid'] != true) {
      throw const AppException(
        'Coupon is invalid, expired, or unavailable for this order',
        code: 'coupon_invalid',
      );
    }
    if (data['couponId'] is! String || data['discount'] is! num) {
      throw const AppException(
        'Coupon service returned an invalid response',
        code: 'coupon_response_invalid',
      );
    }
    return Coupon.fromValidation(code: normalizedCode, data: data);
  }
}

class CouponController extends StateNotifier<AsyncValue<Coupon?>> {
  CouponController(this._repository) : super(const AsyncData(null));

  final CouponRepository _repository;

  Future<void> apply(String code, double subtotal) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.validate(code, subtotal));
  }

  void clear() => state = const AsyncData(null);
}
