import 'package:bookmyplatter/src/core/errors/app_exception.dart';
import 'package:bookmyplatter/src/core/supabase/supabase_providers.dart';
import 'package:bookmyplatter/src/features/reviews/domain/review.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(ref.watch(supabaseClientProvider));
});

final packageReviewsProvider = FutureProvider.family<List<Review>, String>((ref, packageId) {
  return ref.watch(reviewRepositoryProvider).forPackage(packageId);
});

class ReviewRepository {
  const ReviewRepository(this._client);

  final SupabaseClient _client;

  Future<List<Review>> forPackage(String packageId) async {
    final rows = await _client
        .from('reviews')
        .select('id,order_id,rating,comment,created_at')
        .eq('package_id', packageId)
        .order('created_at', ascending: false);
    return [for (final row in rows) Review.fromMap(row)];
  }

  Future<void> submit({
    required String orderId,
    required int rating,
    required String comment,
  }) async {
    final customerId = _client.auth.currentUser?.id;
    if (customerId == null) {
      throw const AppException('Sign in to write a review', code: 'auth_required');
    }
    if (rating < 1 || rating > 5) {
      throw const AppException('Choose a rating from 1 to 5', code: 'rating_invalid');
    }
    final order = await _client
        .from('orders')
        .select('vendor_id,status')
        .eq('id', orderId)
        .eq('customer_id', customerId)
        .single();
    if (order['status'] != 'delivered') {
      throw const AppException('Reviews are available after delivery', code: 'order_not_delivered');
    }
    await _client.from('reviews').insert({
      'order_id': orderId,
      'customer_id': customerId,
      'vendor_id': order['vendor_id'],
      'rating': rating,
      'comment': comment.trim(),
    });
  }
}
