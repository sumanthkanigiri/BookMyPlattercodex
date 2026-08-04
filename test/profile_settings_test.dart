import 'package:bookmyplatter/src/features/profile/application/profile_settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps persisted customer notification and privacy preferences', () {
    final settings = ProfileSettings.fromMaps(
      {'full_name': 'Ananya Rao'},
      {
        'push_notifications': true,
        'sms_notifications': false,
        'email_notifications': true,
        'marketing_notifications': false,
        'analytics_consent': true,
      },
    );

    expect(settings.fullName, 'Ananya Rao');
    expect(settings.push, isTrue);
    expect(settings.sms, isFalse);
    expect(settings.analytics, isTrue);
  });
}
