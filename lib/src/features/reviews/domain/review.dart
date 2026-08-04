class Review {
  const Review({
    required this.id,
    required this.orderId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromMap(Map<String, dynamic> map) => Review(
        id: map['id'] as String,
        orderId: map['order_id'] as String,
        rating: map['rating'] as int,
        comment: map['comment'] as String? ?? '',
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      );

  final String id;
  final String orderId;
  final int rating;
  final String comment;
  final DateTime createdAt;
}
