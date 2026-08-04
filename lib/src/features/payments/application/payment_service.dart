import 'package:bookmyplatter/src/core/errors/app_exception.dart';
import 'package:bookmyplatter/src/core/supabase/supabase_providers.dart';
import 'package:bookmyplatter/src/features/payments/application/payment_gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final paymentServiceProvider = Provider<PaymentService>((ref) {
  final service = PaymentService(ref.watch(supabaseClientProvider));
  ref.onDispose(service.dispose);
  return service;
});

final razorpayAvailabilityProvider = FutureProvider<bool>((ref) async {
  final response = await ref.watch(supabaseClientProvider).functions.invoke('integration-status');
  return response.status >= 200 && response.status < 300 && response.data is Map<String, dynamic> && response.data['razorpay'] == true;
});

class PaymentService {
  PaymentService(this._client);
  final SupabaseClient _client;
  final PaymentGateway _gateway = PaymentGateway();
  bool _processing = false;

  Future<void> pay({required String orderId, String? name, String? phone, String? email}) async {
    if (_processing) throw const AppException('A payment is already in progress');
    _processing = true;
    try {
      final response = await _client.functions.invoke('create-payment-intent', body: {'orderId': orderId});
      final data = response.data;
      if (response.status < 200 || response.status >= 300 || data is! Map<String, dynamic> || data['razorpayOrderId'] is! String) {
        throw const AppException('Unable to initialize Razorpay', code: 'payment_init_failed');
      }
      final result = await _gateway.open({
        'key': data['keyId'],
        'order_id': data['razorpayOrderId'],
        'amount': data['amountPaise'],
        'currency': data['currency'],
        'name': 'BookMyPlatter',
        'description': 'Catering booking payment',
        'prefill': {'name': name ?? '', 'contact': phone ?? '', 'email': email ?? ''},
        'theme': {'color': '#3C1285'},
      });
      final verification = await _client.functions.invoke('verify-payment', body: {
        'razorpayOrderId': result.orderId,
        'razorpayPaymentId': result.paymentId,
        'razorpaySignature': result.signature,
      });
      if (verification.status < 200 || verification.status >= 300 || verification.data is! Map<String, dynamic> || verification.data['verified'] != true) {
        throw const AppException('Payment verification failed', code: 'payment_unverified');
      }
    } on PaymentGatewayException catch (error) {
      await _recordFailure(orderId, error.code, error.message);
      throw AppException(error.message, code: error.code == null ? 'payment_failed' : 'razorpay_${error.code}');
    } finally {
      _processing = false;
    }
  }

  Future<void> _recordFailure(String orderId, String? code, String description) async {
    try {
      await _client.functions.invoke('payment-failed', body: {'orderId': orderId, 'code': code, 'description': description});
    } catch (_) {
      // Gateway errors remain visible even when optional failure telemetry is unavailable.
    }
  }

  void dispose() => _gateway.dispose();
}
