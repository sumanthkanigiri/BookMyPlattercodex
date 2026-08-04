import 'dart:async';

import 'package:bookmyplatter/src/app/book_my_platter_app.dart';
import 'package:bookmyplatter/src/core/notifications/push_notifications.dart';
import 'package:bookmyplatter/src/core/supabase/bootstrap_supabase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapSupabase();
  runApp(const ProviderScope(child: BookMyPlatterApp()));
  unawaited(_initializeOptionalServices());
}

Future<void> _initializeOptionalServices() async {
  try {
    await initializePushNotifications();
  } catch (error) {
    debugPrint(
      'BookMyPlatter developer warning: push notification initialization '
      'failed; the app will continue ($error).',
    );
  }
}
