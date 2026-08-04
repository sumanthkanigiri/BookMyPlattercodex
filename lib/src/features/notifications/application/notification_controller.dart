import 'dart:async';

import 'package:bookmyplatter/src/core/errors/app_exception.dart';
import 'package:bookmyplatter/src/core/supabase/supabase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerNotification {
  const CustomerNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
  });

  factory CustomerNotification.fromMap(Map<String, dynamic> map) => CustomerNotification(
        id: map['id'] as String,
        title: map['title'] as String,
        body: map['body'] as String,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        isRead: map['read_at'] != null,
      );

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(supabaseClientProvider));
});

final notificationControllerProvider = StateNotifierProvider<NotificationController,
    AsyncValue<List<CustomerNotification>>>((ref) {
  return NotificationController(ref.watch(notificationRepositoryProvider));
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationControllerProvider).valueOrNull?.where((item) => !item.isRead).length ?? 0;
});

class NotificationRepository {
  const NotificationRepository(this._client);

  final SupabaseClient _client;

  bool get isAuthenticated => _client.auth.currentUser != null;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AppException('Sign in to view notifications', code: 'auth_required');
    return id;
  }

  Future<List<CustomerNotification>> fetchAll() async {
    final rows = await _client
        .from('notifications')
        .select('id,title,body,read_at,created_at')
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(100);
    return [for (final row in rows) CustomerNotification.fromMap(row)];
  }

  Future<void> markRead(String id) async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('user_id', _userId);
  }

  StreamSubscription<List<Map<String, dynamic>>> subscribe(void Function() onChange) {
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .listen((_) => onChange());
  }
}

class NotificationController extends StateNotifier<AsyncValue<List<CustomerNotification>>> {
  NotificationController(this._repository) : super(const AsyncLoading()) {
    refresh();
    if (_repository.isAuthenticated) {
      _subscription = _repository.subscribe(refresh);
    }
  }

  final NotificationRepository _repository;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.fetchAll);
  }

  Future<void> markRead(String id) async {
    await _repository.markRead(id);
    await refresh();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
