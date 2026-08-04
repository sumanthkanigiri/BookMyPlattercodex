import 'package:bookmyplatter/src/core/supabase/supabase_providers.dart';
import 'package:bookmyplatter/src/features/notifications/application/notification_controller.dart';
import 'package:bookmyplatter/src/features/orders/application/order_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BookMyPlatterShell extends ConsumerWidget {
  const BookMyPlatterShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authenticatedUserIdProvider).valueOrNull;
    final orders = userId == null
        ? const []
        : ref.watch(orderControllerProvider).valueOrNull ?? const [];
    final activeOrders = orders.where((order) => order.isActive).length;
    final unreadNotifications = userId == null
        ? 0
        : ref.watch(unreadNotificationCountProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        indicatorColor: const Color(0xFFD4AF37).withOpacity(.28),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'Search',
          ),
          NavigationDestination(
            icon: _ShellBadge(
              count: activeOrders,
              child: const Icon(Icons.receipt_long_outlined),
            ),
            selectedIcon: _ShellBadge(
              count: activeOrders,
              child: Icon(Icons.receipt_long_rounded, color: scheme.primary),
            ),
            label: 'Bookings',
          ),
          const NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: 'Wishlist',
          ),
          NavigationDestination(
            icon: _ShellBadge(
              count: unreadNotifications,
              child: const Icon(Icons.person_outline_rounded),
            ),
            selectedIcon: _ShellBadge(
              count: unreadNotifications,
              child: Icon(Icons.person_rounded, color: scheme.primary),
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ShellBadge extends StatelessWidget {
  const _ShellBadge({required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    return Badge(
      label: Text(count > 99 ? '99+' : '$count'),
      child: child,
    );
  }
}
