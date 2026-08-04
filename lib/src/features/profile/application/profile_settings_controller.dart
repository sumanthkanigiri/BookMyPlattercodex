import 'package:bookmyplatter/src/core/errors/app_exception.dart';
import 'package:bookmyplatter/src/core/supabase/supabase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileSettings {
  const ProfileSettings({
    required this.fullName,
    required this.push,
    required this.sms,
    required this.email,
    required this.marketing,
    required this.analytics,
  });

  factory ProfileSettings.fromMaps(Map<String, dynamic> profile, Map<String, dynamic>? preferences) => ProfileSettings(
        fullName: profile['full_name'] as String,
        push: preferences?['push_notifications'] as bool? ?? true,
        sms: preferences?['sms_notifications'] as bool? ?? true,
        email: preferences?['email_notifications'] as bool? ?? true,
        marketing: preferences?['marketing_notifications'] as bool? ?? false,
        analytics: preferences?['analytics_consent'] as bool? ?? false,
      );

  final String fullName;
  final bool push;
  final bool sms;
  final bool email;
  final bool marketing;
  final bool analytics;

  ProfileSettings copyWith({String? fullName, bool? push, bool? sms, bool? email, bool? marketing, bool? analytics}) =>
      ProfileSettings(
        fullName: fullName ?? this.fullName,
        push: push ?? this.push,
        sms: sms ?? this.sms,
        email: email ?? this.email,
        marketing: marketing ?? this.marketing,
        analytics: analytics ?? this.analytics,
      );
}

final profileSettingsRepositoryProvider = Provider<ProfileSettingsRepository>((ref) {
  return ProfileSettingsRepository(ref.watch(supabaseClientProvider));
});

final profileSettingsControllerProvider = StateNotifierProvider<ProfileSettingsController,
    AsyncValue<ProfileSettings>>((ref) {
  return ProfileSettingsController(ref.watch(profileSettingsRepositoryProvider));
});

class ProfileSettingsRepository {
  const ProfileSettingsRepository(this._client);
  final SupabaseClient _client;

  String get userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AppException('Sign in to manage settings', code: 'auth_required');
    return id;
  }

  Future<ProfileSettings> load() async {
    final profile = await _client.from('profiles').select('full_name').eq('id', userId).single();
    final preferences = await _client.from('customer_preferences').select().eq('customer_id', userId).maybeSingle();
    return ProfileSettings.fromMaps(profile, preferences);
  }

  Future<void> save(ProfileSettings settings) async {
    final name = settings.fullName.trim();
    if (name.length < 2 || name.length > 80) {
      throw const AppException('Name must contain 2 to 80 characters', code: 'name_invalid');
    }
    await _client.from('profiles').update({'full_name': name}).eq('id', userId);
    await _client.from('customer_preferences').upsert({
      'customer_id': userId,
      'push_notifications': settings.push,
      'sms_notifications': settings.sms,
      'email_notifications': settings.email,
      'marketing_notifications': settings.marketing,
      'analytics_consent': settings.analytics,
    });
  }

  Future<void> deleteAccount() async {
    final response = await _client.functions.invoke('delete-account', method: HttpMethod.delete);
    if (response.data is! Map<String, dynamic> || response.data['deleted'] != true) {
      throw const AppException('Unable to delete account', code: 'delete_failed');
    }
  }
}

class ProfileSettingsController extends StateNotifier<AsyncValue<ProfileSettings>> {
  ProfileSettingsController(this._repository) : super(const AsyncLoading()) { refresh(); }
  final ProfileSettingsRepository _repository;
  Future<void> refresh() async => state = await AsyncValue.guard(_repository.load);
  Future<void> save(ProfileSettings settings) async {
    state = const AsyncLoading();
    try {
      await _repository.save(settings);
      state = AsyncData(settings);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
  Future<void> deleteAccount() => _repository.deleteAccount();
}
