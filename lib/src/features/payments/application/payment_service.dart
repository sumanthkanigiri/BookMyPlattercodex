import 'dart:async';

import 'package:bookmyplatter/src/core/errors/app_exception.dart';
import 'package:bookmyplatter/src/core/supabase/supabase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final paymentServiceProvider = Provider<PaymentService>((ref) {
  final service = PaymentService(ref.watch(supabaseClientProvider));
  ref.onDispose(service.dispose);
  return service;
});

class PaymentService {
  PaymentService(this._client) : _razorpay = Razorpay() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onFailure);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  final SupabaseClient _client;
  final Razorpay _razorpay;
  Completer<void>? _completion;
  String? _orderId;

  Future<void> pay({required String orderId, String? name, String? phone, String? email}) async {
    if (_completion != null) throw const AppException('A payment is already in progress');
    final response = await _client.functions.invoke(
      'create-payment-intent',
      body: {'orderId': orderId},
    );
    final data = response.data;
    if (data is! Map<String, dynamic> || data['razorpayOrderId'] is! String) {
      throw const AppException('Unable to initialize Razorpay', code: 'payment_init_failed');
    }
    _completion = Completer<void>();
    _orderId = orderId;
    _razorpay.open({
      'key': data['keyId'],
      'order_id': data['razorpayOrderId'],
      'amount': data['amountPaise'],
      'currency': data['currency'],
      'name': 'BookMyPlatter',
      'description': 'Catering booking payment',
      'prefill': {'name': name ?? '', 'contact': phone ?? '', 'email': email ?? ''},
      'theme': {'color': '#8B1538'},
    });
    return _completion!.future;
  }

  Future<void> _onSuccess(PaymentSuccessResponse response) async {
    try {
      if (response.orderId == null || response.paymentId == null || response.signature == null) {
        throw const AppException('Razorpay returned an incomplete payment response');
      }
      final verification = await _client.functions.invoke('verify-payment', body: {
        'razorpayOrderId': response.orderId,
        'razorpayPaymentId': response.paymentId,
        'razorpaySignature': response.signature,
      });
      if (verification.data is! Map<String, dynamic> || verification.data['verified'] != true) {
        throw const AppException('Payment verification failed', code: 'payment_unverified');
      }
      _completion?.complete();
    } catch (error, stackTrace) {
      _completion?.completeError(error, stackTrace);
    } finally {
      _completion = null;
      _orderId = null;
    }
  }

  Future<void> _onFailure(PaymentFailureResponse response) async {
    final orderId = _orderId;
    if (orderId != null) {
      try {
        await _client.functions.invoke('payment-failed', body: {
          'orderId': orderId,
          'code': '${response.code}',
          'description': response.message,
        });
      } catch (_) {
        // Preserve the gateway error even if failure telemetry cannot be recorded.
      }
    }
    _completion?.completeError(
      AppException(response.message ?? 'Payment failed', code: 'razorpay_${response.code}'),
    );
    _completion = null;
    _orderId = null;
  }

  void _onExternalWallet(ExternalWalletResponse response) {}

  void dispose() {
    _completion?.completeError(const AppException('Payment was cancelled'));
    _completion = null;
    _orderId = null;
    _razorpay.clear();
  }
}
