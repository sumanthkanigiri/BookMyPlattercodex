import 'package:bookmyplatter/src/core/errors/app_exception.dart';
import 'package:bookmyplatter/src/core/supabase/supabase_providers.dart';
import 'package:bookmyplatter/src/features/address/domain/address.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  return AddressRepository(ref.watch(supabaseClientProvider));
});

final addressControllerProvider =
    StateNotifierProvider<AddressController, AsyncValue<List<Address>>>((ref) {
  return AddressController(ref.watch(addressRepositoryProvider));
});

final serviceAreasProvider = FutureProvider<List<ServiceArea>>((ref) {
  return ref.watch(addressRepositoryProvider).fetchServiceAreas();
});

class ServiceArea {
  const ServiceArea({required this.id, required this.name, required this.city, required this.pincode});
  final String id;
  final String name;
  final String city;
  final String pincode;
}

class AddressRepository {
  const AddressRepository(this._client);

  final SupabaseClient _client;

  String get _customerId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const AppException('Sign in to manage addresses', code: 'auth_required');
    }
    return id;
  }

  Future<List<Address>> fetchAll() async {
    final rows = await _client
        .from('customer_addresses')
        .select('id,label,line1,line2,area_id,is_default,areas(name,pincode,cities(name))')
        .eq('customer_id', _customerId)
        .order('is_default', ascending: false)
        .order('created_at');
    return [for (final row in rows) Address.fromMap(row)];
  }

  Future<List<ServiceArea>> fetchServiceAreas() async {
    final rows = await _client
        .from('areas')
        .select('id,name,pincode,cities(name)')
        .eq('is_active', true)
        .order('name');
    return [
      for (final row in rows)
        ServiceArea(
          id: row['id'] as String,
          name: row['name'] as String,
          city: (row['cities'] as Map<String, dynamic>)['name'] as String,
          pincode: row['pincode'] as String? ?? '',
        ),
    ];
  }

  Future<void> save(Address address) async {
    final values = <String, dynamic>{
      'customer_id': _customerId,
      'label': address.label.trim(),
      'line1': address.line1.trim(),
      'line2': address.line2?.trim(),
      'area_id': address.areaId,
      'is_default': address.isDefault,
    };
    if (address.id.isEmpty) {
      await _client.from('customer_addresses').insert(values);
    } else {
      await _client
          .from('customer_addresses')
          .update(values)
          .eq('id', address.id)
          .eq('customer_id', _customerId);
    }
  }

  Future<void> remove(String id) async {
    await _client
        .from('customer_addresses')
        .delete()
        .eq('id', id)
        .eq('customer_id', _customerId);
  }
}

class AddressController extends StateNotifier<AsyncValue<List<Address>>> {
  AddressController(this._repository) : super(const AsyncLoading()) {
    refresh();
  }

  final AddressRepository _repository;

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.fetchAll);
  }

  Future<void> save(Address address) async {
    await _repository.save(address);
    await refresh();
  }

  Future<void> remove(String id) async {
    await _repository.remove(id);
    await refresh();
  }
}
