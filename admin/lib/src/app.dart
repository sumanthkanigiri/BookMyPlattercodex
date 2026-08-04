import 'package:bookmyplatter_admin/src/core/admin_session.dart';
import 'package:bookmyplatter_admin/src/features/auth/admin_login_screen.dart';
import 'package:bookmyplatter_admin/src/features/dashboard/dashboard_screen.dart';
import 'package:bookmyplatter_admin/src/features/catalog/admin_catalog_screen.dart';
import 'package:bookmyplatter_admin/src/features/orders/admin_orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final adminRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const AdminLoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AdminShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/orders', builder: (_, __) => const AdminOrdersScreen()),
          GoRoute(path: '/catalog', builder: (_, __) => const AdminCatalogScreen()),
        ],
      ),
    ],
  );
});

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(adminIdentityProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3C1285), primary: const Color(0xFF3C1285), secondary: const Color(0xFFF5B300), surface: Colors.white),
        scaffoldBackgroundColor: const Color(0xFFF8F7FB),
        cardTheme: CardThemeData(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), color: Colors.white),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: identity.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) => Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.gpp_bad_outlined, size: 52), const SizedBox(height: 12), Text(error.toString()), const SizedBox(height: 12), FilledButton(onPressed: () => ref.invalidate(adminIdentityProvider), child: const Text('Retry'))]))),
        data: (admin) => admin == null ? const AdminLoginScreen() : MaterialApp.router(debugShowCheckedModeBanner: false, theme: Theme.of(context), routerConfig: ref.watch(adminRouterProvider)),
      ),
    );
  }
}

class AdminShell extends ConsumerWidget {
  const AdminShell({required this.location, required this.child, super.key});
  final String location;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compact = MediaQuery.sizeOf(context).width < 900;
    final index = location.startsWith('/orders') ? 1 : location.startsWith('/catalog') ? 2 : 0;
    const paths = ['/dashboard', '/orders', '/catalog'];
    final destinations = const [NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')), NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: Text('Orders')), NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: Text('Catalog'))];
    return Scaffold(
      appBar: AppBar(title: const Text('BookMyPlatter Operations'), actions: [IconButton(tooltip: 'Sign out', onPressed: () => ref.read(adminAuthRepositoryProvider).signOut(), icon: const Icon(Icons.logout))]),
      body: Row(children: [
        if (!compact)
          NavigationRail(extended: MediaQuery.sizeOf(context).width > 1200, selectedIndex: index, onDestinationSelected: (value) => context.go(paths[value]), destinations: destinations),
        Expanded(child: child),
      ]),
      bottomNavigationBar: compact ? NavigationBar(selectedIndex: index, onDestinationSelected: (value) => context.go(paths[value]), destinations: const [NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'), NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Orders'), NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Catalog')]) : null,
    );
  }
}
