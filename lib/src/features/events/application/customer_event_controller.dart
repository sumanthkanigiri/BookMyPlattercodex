import 'package:bookmyplatter/src/core/errors/app_exception.dart';
import 'package:bookmyplatter/src/core/supabase/supabase_providers.dart';
import 'package:bookmyplatter/src/features/events/domain/customer_event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final customerEventRepositoryProvider = Provider<CustomerEventRepository>((ref) {
  return CustomerEventRepository(ref.watch(supabaseClientProvider));
});

final customerEventsProvider = StateNotifierProvider<CustomerEventsController,
    AsyncValue<List<CustomerEvent>>>((ref) {
  ref.watch(authenticatedUserIdProvider);
  return CustomerEventsController(ref.watch(customerEventRepositoryProvider));
});

class CustomerEventRepository {
  const CustomerEventRepository(this._client);
  final SupabaseClient _client;

  String get customerId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AppException('Sign in to manage events', code: 'auth_required');
    return id;
  }

  Future<List<CustomerEvent>> fetchAll() async {
    final rows = await _client
        .from('customer_events')
        .select('id,event_name,event_type,event_at,venue_name,address_id,guest_count,special_instructions')
        .eq('customer_id', customerId)
        .order('event_at');
    return [for (final row in rows) CustomerEvent.fromMap(row)];
  }

  Future<void> save(CustomerEvent event) async {
    if (event.name.trim().length < 2) {
      throw const AppException('Enter a clear event name', code: 'event_name_invalid');
    }
    if (event.guestCount < 1) {
      throw const AppException('Guest count must be at least 1', code: 'guest_count_invalid');
    }
    final values = event.toMap(customerId);
    if (event.id.isEmpty) {
      await _client.from('customer_events').insert(values);
    } else {
      await _client
          .from('customer_events')
          .update(values)
          .eq('id', event.id)
          .eq('customer_id', customerId);
    }
  }

  Future<void> remove(String id) async {
    await _client
        .from('customer_events')
        .delete()
        .eq('id', id)
        .eq('customer_id', customerId);
  }
}

class CustomerEventsController extends StateNotifier<AsyncValue<List<CustomerEvent>>> {
  CustomerEventsController(this._repository) : super(const AsyncLoading()) {
    refresh();
  }

  final CustomerEventRepository _repository;

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.fetchAll);
  }

  Future<void> save(CustomerEvent event) async {
    await _repository.save(event);
    await refresh();
  }

  Future<void> remove(String id) async {
    await _repository.remove(id);
    await refresh();
  }
}
