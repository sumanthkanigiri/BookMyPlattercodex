import 'package:bookmyplatter/src/core/supabase/bootstrap_supabase.dart';
import 'package:bookmyplatter/src/features/auth/presentation/login_screen.dart';
import 'package:bookmyplatter/src/features/address/presentation/addresses_screen.dart';
import 'package:bookmyplatter/src/features/assistant/presentation/catering_assistant_screen.dart';
import 'package:bookmyplatter/src/features/cart/presentation/cart_screen.dart';
import 'package:bookmyplatter/src/features/checkout/presentation/checkout_screen.dart';
import 'package:bookmyplatter/src/features/home/presentation/home_screen.dart';
import 'package:bookmyplatter/src/features/loyalty/presentation/loyalty_screen.dart';
import 'package:bookmyplatter/src/features/orders/presentation/orders_screen.dart';
import 'package:bookmyplatter/src/features/notifications/presentation/notifications_screen.dart';
import 'package:bookmyplatter/src/features/orders/presentation/order_details_screen.dart';
import 'package:bookmyplatter/src/features/packages/presentation/package_details_screen.dart';
import 'package:bookmyplatter/src/features/profile/presentation/profile_screen.dart';
import 'package:bookmyplatter/src/features/profile/presentation/settings_screen.dart';
import 'package:bookmyplatter/src/features/search/presentation/search_screen.dart';
import 'package:bookmyplatter/src/features/splash/presentation/splash_screen.dart';
import 'package:bookmyplatter/src/features/support/presentation/support_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  errorBuilder: (context, state) => StartupErrorScreen(
    message: state.error?.toString() ?? 'Route not found',
  ),
  redirect: (context, state) {
    if (state.matchedLocation != '/' && !isSupabaseInitialized) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/assistant',
      builder: (context, state) => const CateringAssistantScreen(),
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => SearchScreen(
        initialCategoryId: state.uri.queryParameters['category'],
        initialQuery: state.uri.queryParameters['q'] ?? '',
      ),
    ),
    GoRoute(
      path: '/package/:id',
      builder: (context, state) => PackageDetailsScreen(
        packageId: state.pathParameters['id'] ?? 'featured',
      ),
    ),
    GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
    GoRoute(
      path: '/checkout',
      builder: (context, state) => const CheckoutScreen(),
    ),
    GoRoute(path: '/orders', builder: (context, state) => const OrdersScreen()),
    GoRoute(
      path: '/order/:id',
      builder: (context, state) => OrderDetailsScreen(
        orderId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/confirmation/:id',
      builder: (context, state) => OrderDetailsScreen(
        orderId: state.pathParameters['id']!,
        confirmation: true,
      ),
    ),
    GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(path: '/addresses', builder: (context, state) => const AddressesScreen()),
    GoRoute(path: '/support', builder: (context, state) => const SupportScreen()),
    GoRoute(path: '/rewards', builder: (context, state) => const LoyaltyScreen()),
  ],
);

class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BookMyPlatter')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.route_outlined,
                  color: Theme.of(context).colorScheme.error,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'We could not open that page.',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Restart app'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
