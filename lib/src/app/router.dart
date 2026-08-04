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
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/assistant', builder: (context, state) => const CateringAssistantScreen()),
    GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
    GoRoute(
      path: '/package/:id',
      builder: (context, state) => PackageDetailsScreen(
        packageId: state.pathParameters['id'] ?? 'featured',
      ),
    ),
    GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
    GoRoute(path: '/checkout', builder: (context, state) => const CheckoutScreen()),
    GoRoute(path: '/orders', builder: (context, state) => const OrdersScreen()),
    GoRoute(
      path: '/order/:id',
      builder: (context, state) => OrderDetailsScreen(orderId: state.pathParameters['id']!),
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
    GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
    GoRoute(path: '/addresses', builder: (context, state) => const AddressesScreen()),
    GoRoute(path: '/support', builder: (context, state) => const SupportScreen()),
    GoRoute(path: '/rewards', builder: (context, state) => const LoyaltyScreen()),
  ],
);
