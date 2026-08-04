import 'package:bookmyplatter/src/core/errors/app_exception.dart';
import 'package:bookmyplatter/src/core/supabase/supabase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository(ref.watch(supabaseClientProvider));
});

final favoritesControllerProvider =
    StateNotifierProvider<FavoritesController, AsyncValue<Set<String>>>((ref) {
  ref.watch(authenticatedUserIdProvider);
  return FavoritesController(ref.watch(favoritesRepositoryProvider));
});

class FavoritesRepository {
  const FavoritesRepository(this._client);

  final SupabaseClient _client;

  String get _customerId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const AppException('Sign in to manage favorites', code: 'auth_required');
    }
    return id;
  }

  Future<Set<String>> fetchIds() async {
    final rows = await _client
        .from('favorites')
        .select('package_id')
        .eq('customer_id', _customerId);
    return {for (final row in rows) row['package_id'] as String};
  }

  Future<void> add(String packageId) async {
    await _client.from('favorites').upsert({
      'customer_id': _customerId,
      'package_id': packageId,
    });
  }

  Future<void> remove(String packageId) async {
    await _client
        .from('favorites')
        .delete()
        .eq('customer_id', _customerId)
        .eq('package_id', packageId);
  }
}

class FavoritesController extends StateNotifier<AsyncValue<Set<String>>> {
  FavoritesController(this._repository) : super(const AsyncLoading()) {
    refresh();
  }

  final FavoritesRepository _repository;

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.fetchIds);
  }

  Future<void> toggle(String packageId) async {
    final previous = state.valueOrNull ?? <String>{};
    final removing = previous.contains(packageId);
    final next = {...previous};
    removing ? next.remove(packageId) : next.add(packageId);
    state = AsyncData(next);
    try {
      removing ? await _repository.remove(packageId) : await _repository.add(packageId);
    } catch (error, stackTrace) {
      state = AsyncData(previous);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
