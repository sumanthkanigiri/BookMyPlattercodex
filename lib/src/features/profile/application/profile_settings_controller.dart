import 'package:bookmyplatter/src/core/errors/app_exception.dart';
import 'package:bookmyplatter/src/core/supabase/supabase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileSettings {
  const ProfileSettings({
    required this.fullName,
    required this.mobile,
    required this.email,
    required this.city,
    required this.eventPreferences,
    required this.favouriteCuisines,
    required this.dietaryPreferences,
    required this.gstNumber,
    required this.companyName,
    required this.anniversary,
    required this.birthday,
    required this.push,
    required this.sms,
    required this.emailUpdates,
    required this.marketing,
    required this.analytics,
  });

  factory ProfileSettings.fromMaps(
    Map<String, dynamic> profile,
    Map<String, dynamic>? preferences,
    User? user,
  ) {
    return ProfileSettings(
      fullName: profile['full_name'] as String? ?? '',
      mobile: profile['phone'] as String? ?? user?.phone ?? '',
      email: profile['email'] as String? ?? user?.email ?? '',
      city: profile['city'] as String? ?? '',
      eventPreferences: _stringList(profile['event_preferences']),
      favouriteCuisines: _stringList(profile['favourite_cuisines']),
      dietaryPreferences: _stringList(profile['dietary_preferences']),
      gstNumber: profile['gst_number'] as String? ?? '',
      companyName: profile['company_name'] as String? ?? '',
      anniversary: _date(profile['anniversary']),
      birthday: _date(profile['birthday']),
      push: preferences?['push_notifications'] as bool? ?? true,
      sms: preferences?['sms_notifications'] as bool? ?? true,
      emailUpdates: preferences?['email_notifications'] as bool? ?? true,
      marketing: preferences?['marketing_notifications'] as bool? ?? false,
      analytics: preferences?['analytics_consent'] as bool? ?? false,
    );
  }

  final String fullName;
  final String mobile;
  final String email;
  final String city;
  final List<String> eventPreferences;
  final List<String> favouriteCuisines;
  final List<String> dietaryPreferences;
  final String gstNumber;
  final String companyName;
  final DateTime? anniversary;
  final DateTime? birthday;
  final bool push;
  final bool sms;
  final bool emailUpdates;
  final bool marketing;
  final bool analytics;

  ProfileSettings copyWith({
    String? fullName,
    String? mobile,
    String? email,
    String? city,
    List<String>? eventPreferences,
    List<String>? favouriteCuisines,
    List<String>? dietaryPreferences,
    String? gstNumber,
    String? companyName,
    DateTime? anniversary,
    DateTime? birthday,
    bool clearAnniversary = false,
    bool clearBirthday = false,
    bool? push,
    bool? sms,
    bool? emailUpdates,
    bool? marketing,
    bool? analytics,
  }) {
    return ProfileSettings(
      fullName: fullName ?? this.fullName,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      city: city ?? this.city,
      eventPreferences: eventPreferences ?? this.eventPreferences,
      favouriteCuisines: favouriteCuisines ?? this.favouriteCuisines,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      gstNumber: gstNumber ?? this.gstNumber,
      companyName: companyName ?? this.companyName,
      anniversary: clearAnniversary ? null : anniversary ?? this.anniversary,
      birthday: clearBirthday ? null : birthday ?? this.birthday,
      push: push ?? this.push,
      sms: sms ?? this.sms,
      emailUpdates: emailUpdates ?? this.emailUpdates,
      marketing: marketing ?? this.marketing,
      analytics: analytics ?? this.analytics,
    );
  }

  Map<String, dynamic> profileUpdate(String userId) => {
        'id': userId,
        'full_name': fullName.trim(),
        'phone': mobile.trim().isEmpty ? null : mobile.trim(),
        'email': email.trim().isEmpty ? null : email.trim(),
        'city': city.trim(),
        'event_preferences': eventPreferences,
        'favourite_cuisines': favouriteCuisines,
        'dietary_preferences': dietaryPreferences,
        'gst_number': gstNumber.trim().isEmpty ? null : gstNumber.trim(),
        'company_name': companyName.trim().isEmpty ? null : companyName.trim(),
        'anniversary': anniversary?.toIso8601String().split('T').first,
        'birthday': birthday?.toIso8601String().split('T').first,
      };
}

List<String> _stringList(Object? value) {
  if (value is List) return [for (final item in value) '$item'];
  return const [];
}

DateTime? _date(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse('$value');
}

final profileSettingsRepositoryProvider = Provider<ProfileSettingsRepository>((ref) {
  return ProfileSettingsRepository(ref.watch(supabaseClientProvider));
});

final profileSettingsControllerProvider = StateNotifierProvider<ProfileSettingsController,
    AsyncValue<ProfileSettings>>((ref) {
  ref.watch(authenticatedUserIdProvider);
  return ProfileSettingsController(ref.watch(profileSettingsRepositoryProvider));
});

class ProfileSettingsRepository {
  const ProfileSettingsRepository(this._client);
  final SupabaseClient _client;

  String get userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const AppException('Sign in to manage settings', code: 'auth_required');
    }
    return id;
  }

  Future<ProfileSettings> load() async {
    final profile = await _client
        .from('profiles')
        .select('full_name,phone,email,city,event_preferences,favourite_cuisines,dietary_preferences,gst_number,company_name,anniversary,birthday')
        .eq('id', userId)
        .single();
    final preferences = await _client
        .from('customer_preferences')
        .select()
        .eq('customer_id', userId)
        .maybeSingle();
    return ProfileSettings.fromMaps(profile, preferences, _client.auth.currentUser);
  }

  Future<void> save(ProfileSettings settings) async {
    final name = settings.fullName.trim();
    if (name.length < 2 || name.length > 80) {
      throw const AppException('Name must contain 2 to 80 characters', code: 'name_invalid');
    }
    final email = settings.email.trim();
    if (email.isNotEmpty && !email.contains('@')) {
      throw const AppException('Enter a valid email address', code: 'email_invalid');
    }
    await _client.auth.updateUser(
      UserAttributes(
        email: email.isEmpty ? null : email,
        data: {'full_name': name},
      ),
    );
    await _client.from('profiles').upsert(settings.profileUpdate(userId));
    await _client.from('customer_preferences').upsert({
      'customer_id': userId,
      'push_notifications': settings.push,
      'sms_notifications': settings.sms,
      'email_notifications': settings.emailUpdates,
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
  ProfileSettingsController(this._repository) : super(const AsyncLoading()) {
    refresh();
  }

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
