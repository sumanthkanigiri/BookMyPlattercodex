import 'package:bookmyplatter/src/core/supabase/supabase_providers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final startupRepositoryProvider = Provider<StartupRepository>((ref) {
  return StartupRepository(
    ref.watch(supabaseClientProvider),
    Connectivity(),
  );
});

final startupProvider = FutureProvider<bool>((ref) {
  return ref.watch(startupRepositoryProvider).initialize();
});

class StartupRepository {
  const StartupRepository(this._client, this._connectivity);

  final SupabaseClient _client;
  final Connectivity _connectivity;

  Future<bool> initialize() async {
    final connections = await _connectivity.checkConnectivity();
    if (connections.every((result) => result == ConnectivityResult.none)) {
      throw const SocketException('No internet connection');
    }

    await _client.from('app_config').select('key,value').eq('is_public', true);
    return _client.auth.currentSession != null;
  }
}

class SocketException implements Exception {
  const SocketException(this.message);
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
    initialize();
  }

  Future<void> initialize() async {
    setState(() => errorMessage = null);
    try {
      ref.invalidate(startupProvider);
      final signedIn = await ref.read(startupProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) context.go(signedIn ? '/home' : '/login');
    } catch (error) {
      if (mounted) setState(() => errorMessage = error.toString());
    }
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
          child: Padding(
            padding: const EdgeInsets.all(24),
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
                Text('BookMyPlatter', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text('Catering made simple'),
                const SizedBox(height: 28),
                if (errorMessage == null)
                  const CircularProgressIndicator()
                else ...[
                  Text(errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: initialize,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
