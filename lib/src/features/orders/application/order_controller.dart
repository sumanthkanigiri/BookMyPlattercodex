import 'dart:async';

import 'package:bookmyplatter/src/core/errors/app_exception.dart';
import 'package:bookmyplatter/src/core/supabase/supabase_providers.dart';
import 'package:bookmyplatter/src/features/address/domain/address.dart';
import 'package:bookmyplatter/src/features/cart/domain/cart_item.dart';
import 'package:bookmyplatter/src/features/coupons/domain/coupon.dart';
import 'package:bookmyplatter/src/features/orders/domain/order.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.watch(supabaseClientProvider));
});

final orderControllerProvider =
    StateNotifierProvider<OrderController, AsyncValue<List<PlatterOrder>>>((ref) {
  ref.watch(authenticatedUserIdProvider);
  return OrderController(ref.watch(orderRepositoryProvider));
});

final orderProvider = FutureProvider.family<PlatterOrder, String>((ref, id) {
  return ref.watch(orderRepositoryProvider).fetchById(id);
});

class CustomerDeliveryTracking {
  const CustomerDeliveryTracking({required this.status, this.latitude, this.longitude, this.estimatedArrival, this.deliveredAt});
  factory CustomerDeliveryTracking.fromMap(Map<String, dynamic> map) => CustomerDeliveryTracking(
        status: map['status'] as String,
        latitude: (map['current_latitude'] as num?)?.toDouble(),
        longitude: (map['current_longitude'] as num?)?.toDouble(),
        estimatedArrival: map['estimated_arrival_at'] == null ? null : DateTime.parse(map['estimated_arrival_at'] as String).toLocal(),
        deliveredAt: map['delivered_at'] == null ? null : DateTime.parse(map['delivered_at'] as String).toLocal(),
      );
  final String status;
  final double? latitude;
  final double? longitude;
  final DateTime? estimatedArrival;
  final DateTime? deliveredAt;
}

final deliveryTrackingProvider = StreamProvider.autoDispose.family<CustomerDeliveryTracking?, String>((ref, orderId) async* {
  final repository = ref.watch(orderRepositoryProvider);
  while (true) {
    yield await repository.deliveryTracking(orderId);
    await Future<void>.delayed(const Duration(seconds: 20));
  }
});

class OrderRepository {
  const OrderRepository(this._client);

  final SupabaseClient _client;

  String get _customerId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AppException('Sign in to place an order', code: 'auth_required');
    return id;
  }

  Future<List<PlatterOrder>> fetchAll() async {
    final rows = await _client
        .from('orders')
        .select('id,guest_count,event_at,event_type,payment_method,notes,cancellation_reason,delivery_address,subtotal,discount_total,tax_total,grand_total,status,created_at,packages(name,image_url),order_status_events(status,message,created_at)')
        .eq('customer_id', _customerId)
        .order('created_at', ascending: false);
    return [for (final row in rows) PlatterOrder.fromMap(row)];
  }

  Future<PlatterOrder> fetchById(String id) async {
    final row = await _client
        .from('orders')
        .select('id,guest_count,event_at,event_type,payment_method,notes,cancellation_reason,delivery_address,subtotal,discount_total,tax_total,grand_total,status,created_at,packages(name,image_url),order_status_events(status,message,created_at)')
        .eq('id', id)
        .eq('customer_id', _customerId)
        .single();
    return PlatterOrder.fromMap(row);
  }

  Future<CustomerDeliveryTracking?> deliveryTracking(String orderId) async {
    final rows = await _client.rpc<List<dynamic>>('customer_delivery_tracking', params: {'p_order_id': orderId});
    if (rows.isEmpty) return null;
    return CustomerDeliveryTracking.fromMap(Map<String, dynamic>.from(rows.first as Map));
  }

  Future<List<String>> place({
    required List<CartItem> items,
    required Address address,
    required DateTime eventAt,
    required String eventType,
    required String paymentMethod,
    String? notes,
    Coupon? coupon,
  }) async {
    if (items.isEmpty) throw const AppException('Cart is empty', code: 'cart_empty');
    if (!eventAt.isAfter(DateTime.now())) {
      throw const AppException('Choose a future event date and time', code: 'event_time_invalid');
    }

    final addressText = [
      address.line1,
      if (address.line2 != null && address.line2!.isNotEmpty) address.line2!,
      address.area,
      address.city,
      address.pincode,
    ].join(', ');
    final result = await _client.rpc<List<dynamic>>('place_customer_orders', params: {
      'p_items': [
        for (final item in items)
          {'package_id': item.package.id, 'guest_count': item.guests},
      ],
      'p_coupon_id': coupon?.id,
      'p_event_at': eventAt.toUtc().toIso8601String(),
      'p_event_type': eventType,
      'p_delivery_area_id': address.areaId,
      'p_delivery_address': addressText,
      'p_payment_method': paymentMethod,
      'p_notes': notes,
    });
    return result.cast<String>();
  }

  Future<void> cancel(String orderId, String reason) {
    return _client.rpc<void>(
      'cancel_customer_order',
      params: {'p_order_id': orderId, 'p_reason': reason},
    );
  }

  Future<void> reschedule(String orderId, DateTime eventAt) {
    return _client.rpc<void>('reschedule_customer_order', params: {
      'p_order_id': orderId,
      'p_event_at': eventAt.toUtc().toIso8601String(),
    });
  }

  StreamSubscription<List<Map<String, dynamic>>> subscribe(void Function() onChange) {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('customer_id', _customerId)
        .listen((_) => onChange());
  }
}

class OrderController extends StateNotifier<AsyncValue<List<PlatterOrder>>> {
  OrderController(this._repository) : super(const AsyncLoading()) {
    refresh();
    _subscription = _repository.subscribe(() => refresh(showLoading: false));
  }

  final OrderRepository _repository;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

  Future<void> refresh({bool showLoading = true}) async {
    if (showLoading || state.valueOrNull == null) state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.fetchAll);
  }

  Future<List<String>> placeOrder({
    required List<CartItem> items,
    required Address address,
    required DateTime eventAt,
    required String eventType,
    required String paymentMethod,
    String? notes,
    Coupon? coupon,
  }) async {
    final orderIds = await _repository.place(
      items: items,
      address: address,
      eventAt: eventAt,
      eventType: eventType,
      paymentMethod: paymentMethod,
      notes: notes,
      coupon: coupon,
    );
    await refresh();
    return orderIds;
  }

  Future<void> cancel(String orderId, String reason) async {
    await _repository.cancel(orderId, reason);
    await refresh();
  }

  Future<void> reschedule(String orderId, DateTime eventAt) async {
    await _repository.reschedule(orderId, eventAt);
    await refresh();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
