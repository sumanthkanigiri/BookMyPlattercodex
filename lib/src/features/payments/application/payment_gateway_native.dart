import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

class GatewayPaymentResult {
  const GatewayPaymentResult({required this.orderId, required this.paymentId, required this.signature});
  final String orderId;
  final String paymentId;
  final String signature;
}

class PaymentGatewayException implements Exception {
  const PaymentGatewayException(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => message;
}

class PaymentGateway {
  PaymentGateway() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _success);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _failure);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _wallet);
  }

  final Razorpay _razorpay = Razorpay();
  Completer<GatewayPaymentResult>? _completer;

  Future<GatewayPaymentResult> open(Map<String, dynamic> options) {
    if (_completer != null) return Future.error(const PaymentGatewayException('A payment is already in progress'));
    _completer = Completer<GatewayPaymentResult>();
    _razorpay.open(options);
    return _completer!.future;
  }

  void _success(PaymentSuccessResponse response) {
    final orderId = response.orderId, paymentId = response.paymentId, signature = response.signature;
    if (orderId == null || paymentId == null || signature == null) {
      _finishError(const PaymentGatewayException('Razorpay returned an incomplete payment response'));
      return;
    }
    _completer?.complete(GatewayPaymentResult(orderId: orderId, paymentId: paymentId, signature: signature));
    _completer = null;
  }

  void _failure(PaymentFailureResponse response) => _finishError(PaymentGatewayException(response.message ?? 'Payment failed', code: '${response.code}'));
  void _wallet(ExternalWalletResponse response) => _finishError(PaymentGatewayException('External wallet ${response.walletName ?? ''} requires completion in Razorpay'));
  void _finishError(Object error) { _completer?.completeError(error); _completer = null; }
  void dispose() { _finishError(const PaymentGatewayException('Payment was cancelled')); _razorpay.clear(); }
}
