import 'package:bookmyplatter/src/app/router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> initializePushNotifications() async {
  try {
    await Firebase.initializeApp(options: kIsWeb ? const FirebaseOptions(
      apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
      appId: String.fromEnvironment('FIREBASE_APP_ID'),
      messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
      projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
      authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
      storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    ) : null);
  } on FirebaseException catch (error) {
    debugPrint('BookMyPlatter developer warning: Firebase is not configured; push notifications are disabled (${error.code}).');
    return;
  }
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);
  Future<void> register(String? token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || token == null || token.length < 20) return;
    final platform = kIsWeb ? 'web' : defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    await Supabase.instance.client.rpc<void>('register_device_token', params: {'p_token': token, 'p_platform': platform});
  }
  const vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');
  Future<String?> token() => messaging.getToken(vapidKey: kIsWeb && vapidKey.isNotEmpty ? vapidKey : null);
  await register(await token());
  messaging.onTokenRefresh.listen(register);
  Supabase.instance.client.auth.onAuthStateChange.listen((event) async { if (event.session != null) await register(await token()); });
  void navigate(RemoteMessage message) {
    final orderId = message.data['orderId']?.toString();
    if (orderId != null && RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(orderId)) appRouter.go('/order/$orderId');
  }
  FirebaseMessaging.onMessageOpenedApp.listen(navigate);
  final initial = await messaging.getInitialMessage();
  if (initial != null) navigate(initial);
}
