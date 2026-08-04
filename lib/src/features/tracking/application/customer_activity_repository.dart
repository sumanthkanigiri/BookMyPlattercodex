import 'package:bookmyplatter/src/core/supabase/supabase_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final customerActivityRepositoryProvider = Provider<CustomerActivityRepository>((ref) {
  return CustomerActivityRepository(ref.watch(supabaseClientProvider));
});

class CustomerActivityRepository {
  const CustomerActivityRepository(this._client);

  final SupabaseClient _client;

  Future<String> record({
    required String activityType,
    String anonymousId = '',
    String pagePath = '',
    String? packageId,
    String searchQuery = '',
    Map<String, dynamic> metadata = const {},
  }) async {
    final id = await _client.rpc<String>('record_customer_activity', params: {
      'p_activity_type': activityType,
      'p_anonymous_id': anonymousId,
      'p_page_path': pagePath,
      'p_package_id': packageId,
      'p_search_query': searchQuery.trim(),
      'p_device_info': deviceInfo(),
      'p_metadata': metadata,
    });
    return id;
  }

  Future<void> appOpen({String pagePath = '/'}) => record(
        activityType: kIsWeb ? 'website_visit' : 'app_open',
        pagePath: pagePath,
      ).silently();

  Future<void> packageViewed(String packageId, {String pagePath = ''}) => record(
        activityType: 'package_viewed',
        packageId: packageId,
        pagePath: pagePath.isEmpty ? '/package/$packageId' : pagePath,
      ).silently();

  Future<void> search(String query) {
    if (query.trim().length < 2) return Future.value();
    return record(activityType: 'search', searchQuery: query).silently();
  }

  Future<void> favourite(String packageId) => record(
        activityType: 'favourite',
        packageId: packageId,
      ).silently();

  Future<void> cartAdded(String packageId, {int? guests}) => record(
        activityType: 'cart_added',
        packageId: packageId,
        metadata: {if (guests != null) 'guest_count': guests},
      ).silently();

  Future<void> whatsappClick() => record(activityType: 'whatsapp_click').silently();
  Future<void> callClick() => record(activityType: 'call_click').silently();
}

Map<String, dynamic> deviceInfo() {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  final view = views.isEmpty ? null : views.first;
  return {
    'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    'is_web': kIsWeb,
    'locale': WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag(),
    if (view != null) 'pixel_ratio': view.devicePixelRatio,
    if (view != null) 'width': view.physicalSize.width,
    if (view != null) 'height': view.physicalSize.height,
  };
}
extension _IgnoreFuture<T> on Future<T> {
  Future<void> silently() async {
    try {
      await this;
    } catch (_) {
      return;
    }
  }
}
