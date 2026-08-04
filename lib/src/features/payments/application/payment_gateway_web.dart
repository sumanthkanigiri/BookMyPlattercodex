import 'dart:async';
import 'dart:js';

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
  Completer<GatewayPaymentResult>? _completer;

  Future<GatewayPaymentResult> open(Map<String, dynamic> options) {
    if (_completer != null) return Future.error(const PaymentGatewayException('A payment is already in progress'));
    final constructor = context['Razorpay'];
    if (constructor == null) return Future.error(const PaymentGatewayException('Razorpay checkout failed to load. Check your connection and retry.'));
    _completer = Completer<GatewayPaymentResult>();
    final webOptions = Map<String, dynamic>.from(options)
      ..['handler'] = allowInterop((dynamic response) {
        final result = response is JsObject ? response : JsObject.fromBrowserObject(response as Object);
        final orderId = result['razorpay_order_id']?.toString();
        final paymentId = result['razorpay_payment_id']?.toString();
        final signature = result['razorpay_signature']?.toString();
        if (orderId == null || paymentId == null || signature == null) {
          _finishError(const PaymentGatewayException('Razorpay returned an incomplete payment response'));
        } else {
          _completer?.complete(GatewayPaymentResult(orderId: orderId, paymentId: paymentId, signature: signature));
          _completer = null;
        }
      })
      ..['modal'] = {'ondismiss': allowInterop(() => _finishError(const PaymentGatewayException('Payment was cancelled')))};
    final checkout = JsObject(constructor, [JsObject.jsify(webOptions)]);
    checkout.callMethod<void>('open');
    return _completer!.future;
  }

  void _finishError(Object error) { _completer?.completeError(error); _completer = null; }
  void dispose() => _finishError(const PaymentGatewayException('Payment was cancelled'));
}
