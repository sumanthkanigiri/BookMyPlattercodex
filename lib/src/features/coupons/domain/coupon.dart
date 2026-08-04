class Coupon {
  const Coupon({
    required this.code,
    required this.minimumSubtotal,
    required this.discountPercent,
    this.id,
    this.discountAmount = 0,
  });

  factory Coupon.fromValidation({
    required String code,
    required Map<String, dynamic> data,
  }) {
    return Coupon(
      id: data['couponId'] as String,
      code: code.trim().toUpperCase(),
      minimumSubtotal: 0,
      discountPercent: 0,
      discountAmount: (data['discount'] as num).toDouble(),
    );
  }

  final String? id;
  final String code;
  final double minimumSubtotal;
  final double discountPercent;
  final double discountAmount;

  double discountFor(double subtotal) {
    if (subtotal < minimumSubtotal) return 0;
    final percentageDiscount = subtotal * discountPercent / 100;
    return (discountAmount > percentageDiscount ? discountAmount : percentageDiscount)
        .clamp(0, subtotal)
        .toDouble();
  }
}
