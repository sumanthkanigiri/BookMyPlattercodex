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
  Future<GatewayPaymentResult> open(Map<String, dynamic> options) => Future.error(const PaymentGatewayException('Razorpay is unavailable on this platform'));
  void dispose() {}
}
