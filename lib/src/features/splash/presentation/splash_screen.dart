import 'dart:async';

import 'package:bookmyplatter/src/core/notifications/push_notifications.dart';
import 'package:bookmyplatter/src/core/supabase/bootstrap_supabase.dart';
import 'package:bookmyplatter/src/features/tracking/application/customer_activity_repository.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final startupProvider = FutureProvider<bool>((ref) async {
  await ref.watch(supabaseBootstrapProvider.future);
  return StartupRepository(
    Supabase.instance.client,
    Connectivity(),
  ).initialize();
});

class StartupRepository {
  const StartupRepository(this._client, this._connectivity);

  static const startupTimeout = Duration(seconds: 8);

  final SupabaseClient _client;
  final Connectivity _connectivity;

  Future<bool> initialize() async {
    final connections = await _connectivity.checkConnectivity().timeout(
      startupTimeout,
      onTimeout: () => throw TimeoutException(
        'Network status check timed out. Please try again.',
      ),
    );
    if (connections.every((result) => result == ConnectivityResult.none)) {
      throw const StartupException(
        'No internet connection. Please reconnect and try again.',
      );
    }

    await _client
        .from('app_config')
        .select('key,value')
        .eq('is_public', true)
        .timeout(
          startupTimeout,
          onTimeout: () => throw TimeoutException(
            'BookMyPlatter configuration could not be loaded. Please try again.',
          ),
        );
    return _client.auth.currentSession != null;
  }
}

class StartupException implements Exception {
  const StartupException(this.message);
  final String message;

  @override
  String toString() => message;
}

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController animationController;
  late final Animation<double> scaleAnimation;
  String? errorMessage;
  var _isLoading = false;

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    scaleAnimation = Tween<double>(begin: .92, end: 1.05).animate(
      CurvedAnimation(parent: animationController, curve: Curves.easeInOut),
    );
    unawaited(initialize());
  }

  Future<void> initialize() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      errorMessage = null;
    });
    try {
      ref
        ..invalidate(supabaseBootstrapProvider)
        ..invalidate(startupProvider);
      final signedIn = await ref.read(startupProvider.future).timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw TimeoutException(
              'Startup timed out. Please verify your connection and try again.',
            ),
          );
      await ref.read(customerActivityRepositoryProvider).appOpen();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      context.go(signedIn ? '/home' : '/login');
      unawaited(
        initializePushNotifications().catchError(
          (Object error, StackTrace stackTrace) {
            debugPrint(
              'BookMyPlatter developer warning: push notifications disabled '
              '($error).',
            );
            debugPrintStack(stackTrace: stackTrace);
          },
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          errorMessage = _friendlyStartupMessage(error);
          _isLoading = false;
        });
      }
    }
  }

  String _friendlyStartupMessage(Object error) {
    if (error is TimeoutException) {
      return error.message ?? 'Startup timed out. Please try again.';
    }
    if (error is StartupException) return error.message;
    final message = error.toString().replaceFirst('Bad state: ', '');
    if (message.contains('Missing Supabase environment variables')) {
      return '$message\n\n'
          'Developer warning: configure the missing --dart-define values to '
          'connect to Supabase.';
    }
    return message;
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: scaleAnimation,
                    child: Icon(
                      Icons.restaurant_menu,
                      size: 88,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'BookMyPlatter',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Catering made simple'),
                  const SizedBox(height: 28),
                  if (errorMessage == null) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Preparing your platter experience...'),
                  ] else ...[
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed:
                          _isLoading ? null : () => unawaited(initialize()),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
