import 'package:bookmyplatter/src/core/errors/app_exception.dart';
import 'package:bookmyplatter/src/core/supabase/supabase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoyaltyTransaction {
  const LoyaltyTransaction({
    required this.kind,
    required this.description,
    required this.pointsDelta,
    required this.amountDelta,
    required this.createdAt,
  });

  factory LoyaltyTransaction.fromMap(Map<String, dynamic> map) => LoyaltyTransaction(
        kind: map['kind'] as String,
        description: map['description'] as String,
        pointsDelta: (map['points_delta'] as num).toInt(),
        amountDelta: (map['amount_delta'] as num).toDouble(),
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      );

  final String kind;
  final String description;
  final int pointsDelta;
  final double amountDelta;
  final DateTime createdAt;
}

class LoyaltySummary {
  const LoyaltySummary({
    required this.points,
    required this.walletBalance,
    required this.referralCode,
    required this.transactions,
  });

  final int points;
  final double walletBalance;
  final String referralCode;
  final List<LoyaltyTransaction> transactions;
}

final loyaltyRepositoryProvider = Provider<LoyaltyRepository>((ref) {
  return LoyaltyRepository(ref.watch(supabaseClientProvider));
});

final loyaltyControllerProvider =
    StateNotifierProvider<LoyaltyController, AsyncValue<LoyaltySummary>>((ref) {
  ref.watch(authenticatedUserIdProvider);
  return LoyaltyController(ref.watch(loyaltyRepositoryProvider));
});

class LoyaltyRepository {
  const LoyaltyRepository(this._client);

  final SupabaseClient _client;

  String get _customerId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const AppException('Sign in to view rewards', code: 'auth_required');
    }
    return id;
  }

  Future<LoyaltySummary> fetch() async {
    final account = await _client
        .from('loyalty_accounts')
        .select('points,wallet_balance,referral_code')
        .eq('customer_id', _customerId)
        .single();
    final rows = await _client
        .from('loyalty_transactions')
        .select('kind,description,points_delta,amount_delta,created_at')
        .eq('customer_id', _customerId)
        .order('created_at', ascending: false)
        .limit(50);
    return LoyaltySummary(
      points: (account['points'] as num).toInt(),
      walletBalance: (account['wallet_balance'] as num).toDouble(),
      referralCode: account['referral_code'] as String,
      transactions: [for (final row in rows) LoyaltyTransaction.fromMap(row)],
    );
  }

  Future<void> applyReferralCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{6,16}$').hasMatch(normalized)) {
      throw const AppException('Enter a valid referral code', code: 'invalid_referral_code');
    }
    await _client.rpc<void>('apply_customer_referral', params: {'p_code': normalized});
  }
}

class LoyaltyController extends StateNotifier<AsyncValue<LoyaltySummary>> {
  LoyaltyController(this._repository) : super(const AsyncLoading()) {
    refresh();
  }

  final LoyaltyRepository _repository;

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.fetch);
  }

  Future<void> applyReferralCode(String code) async {
    await _repository.applyReferralCode(code);
    await refresh();
  }
}
