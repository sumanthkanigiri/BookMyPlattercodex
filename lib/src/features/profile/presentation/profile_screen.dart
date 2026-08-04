import 'package:bookmyplatter/src/features/address/application/address_controller.dart';
import 'package:bookmyplatter/src/features/favorites/application/favorites_controller.dart';
import 'package:bookmyplatter/src/features/auth/data/auth_repository.dart';
import 'package:bookmyplatter/src/features/notifications/application/notification_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressControllerProvider);
    final favorites = ref.watch(favoritesControllerProvider);
    final auth = ref.watch(authRepositoryProvider);
    final user = auth.currentUser;
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(user?.userMetadata?['full_name'] as String? ?? 'BookMyPlatter Customer'),
            subtitle: Text(user?.email ?? user?.phone ?? 'Not signed in'),
          ),
          if (user == null)
            ListTile(leading: const Icon(Icons.login), title: const Text('Sign in'), onTap: () => context.go('/login'))
          else
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () async {
                await auth.signOut();
                if (context.mounted) context.go('/login');
              },
            ),
          addresses.when(
            loading: () => const ListTile(
              leading: Icon(Icons.location_on),
              title: Text('Loading saved addresses…'),
              trailing: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (error, _) => ListTile(
              leading: const Icon(Icons.location_off_outlined),
              title: const Text('Saved addresses unavailable'),
              subtitle: Text(error.toString()),
              trailing: IconButton(
                onPressed: () => ref.read(addressControllerProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
              ),
            ),
            data: (items) => ListTile(
              leading: const Icon(Icons.location_on),
              title: Text('${items.length} saved ${items.length == 1 ? 'address' : 'addresses'}'),
            ),
          ),
          favorites.when(
            loading: () => const ListTile(
              leading: Icon(Icons.favorite_border),
              title: Text('Loading favorites…'),
            ),
            error: (error, _) => ListTile(
              leading: const Icon(Icons.favorite_border),
              title: const Text('Favorites unavailable'),
              trailing: IconButton(
                onPressed: () => ref.read(favoritesControllerProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
              ),
            ),
            data: (items) => ListTile(
              leading: const Icon(Icons.favorite),
              title: Text('${items.length} favorite ${items.length == 1 ? 'package' : 'packages'}'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            trailing: unreadNotifications == 0
                ? null
                : Badge(label: Text('$unreadNotifications')),
          ),
          const ListTile(leading: Icon(Icons.support_agent), title: Text('Support')),
          const ListTile(leading: Icon(Icons.settings), title: Text('Settings')),
        ],
      ),
    );
  }
}
