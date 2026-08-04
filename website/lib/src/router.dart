import 'package:bookmyplatter/src/features/address/presentation/addresses_screen.dart';
import 'package:bookmyplatter/src/features/assistant/presentation/catering_assistant_screen.dart';
import 'package:bookmyplatter/src/features/auth/presentation/login_screen.dart';
import 'package:bookmyplatter/src/features/cart/presentation/cart_screen.dart';
import 'package:bookmyplatter/src/features/checkout/presentation/checkout_screen.dart';
import 'package:bookmyplatter/src/features/orders/presentation/order_details_screen.dart';
import 'package:bookmyplatter/src/features/orders/presentation/orders_screen.dart';
import 'package:bookmyplatter/src/features/notifications/presentation/notifications_screen.dart';
import 'package:bookmyplatter/src/features/loyalty/presentation/loyalty_screen.dart';
import 'package:bookmyplatter/src/features/packages/presentation/package_details_screen.dart';
import 'package:bookmyplatter/src/features/profile/presentation/profile_screen.dart';
import 'package:bookmyplatter/src/features/profile/presentation/settings_screen.dart';
import 'package:bookmyplatter/src/features/search/presentation/search_screen.dart';
import 'package:bookmyplatter/src/features/support/presentation/support_screen.dart';
import 'package:bookmyplatter_website/src/site_pages.dart';
import 'package:bookmyplatter_website/src/site_shell.dart';
import 'package:go_router/go_router.dart';

final websiteRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => SiteShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (_, __) => const WebsiteHomePage()),
        GoRoute(path: '/home', builder: (_, __) => const WebsiteHomePage()),
        GoRoute(path: '/packages/veg', builder: (_, __) => const PackageListingPage(type: 'veg', title: 'Veg Packages')),
        GoRoute(path: '/packages/non-veg', builder: (_, __) => const PackageListingPage(type: 'non_veg', title: 'Non-Veg Packages')),
        GoRoute(path: '/packages/platter-box', builder: (_, __) => const PackageListingPage(type: 'platter_box', title: 'Platter Box')),
        GoRoute(path: '/packages/catering-combos', builder: (_, __) => const PackageListingPage(type: 'catering_combo', title: 'Catering Combos')),
        GoRoute(path: '/about', builder: (_, __) => const ContentPage(kind: ContentKind.about)),
        GoRoute(path: '/privacy', builder: (_, __) => const ContentPage(kind: ContentKind.privacy)),
        GoRoute(path: '/terms', builder: (_, __) => const ContentPage(kind: ContentKind.terms)),
      ],
    ),
    GoRoute(path: '/planner', builder: (_, __) => const CateringAssistantScreen()),
    GoRoute(path: '/assistant', redirect: (_, __) => '/planner'),
    GoRoute(path: '/search', builder: (_, state) => SearchScreen(initialCategoryId: state.uri.queryParameters['category'], initialQuery: state.uri.queryParameters['q'] ?? '')),
    GoRoute(path: '/package/:id', builder: (_, state) => PackageDetailsScreen(packageId: state.pathParameters['id']!)),
    GoRoute(path: '/cart', builder: (_, __) => const CartScreen()),
    GoRoute(path: '/checkout', builder: (_, __) => const CheckoutScreen()),
    GoRoute(path: '/orders', builder: (_, __) => const OrdersScreen()),
    GoRoute(path: '/order/:id', builder: (_, state) => OrderDetailsScreen(orderId: state.pathParameters['id']!)),
    GoRoute(path: '/confirmation/:id', builder: (_, state) => OrderDetailsScreen(orderId: state.pathParameters['id']!, confirmation: true)),
    GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
    GoRoute(path: '/rewards', builder: (_, __) => const LoyaltyScreen()),
    GoRoute(path: '/addresses', builder: (_, __) => const AddressesScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/contact', builder: (_, __) => const SupportScreen()),
    GoRoute(path: '/support', builder: (_, __) => const SupportScreen()),
    GoRoute(path: '/faq', builder: (_, __) => const SupportScreen()),
  ],
);
