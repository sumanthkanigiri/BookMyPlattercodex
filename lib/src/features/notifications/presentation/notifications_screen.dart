import 'package:bookmyplatter/src/features/notifications/application/notification_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: notifications.when(
        loading: () => const _NotificationSkeleton(),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 12),
              const Text('Unable to load notifications'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => ref.read(notificationControllerProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (items) => items.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none, size: 64),
                    SizedBox(height: 12),
                    Text('You’re all caught up'),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () => ref.read(notificationControllerProvider.notifier).refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      color: item.isRead ? Colors.white : const Color(0xFFF0E9FC),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: item.isRead ? const Color(0xFFE8E3F0) : const Color(0xFF3C1285),
                          child: Icon(Icons.notifications, color: item.isRead ? Colors.black54 : Colors.white),
                        ),
                        title: Text(item.title, style: TextStyle(fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700)),
                        subtitle: Text('${item.body}\n${DateFormat('d MMM, h:mm a').format(item.createdAt)}'),
                        isThreeLine: true,
                        onTap: item.isRead
                            ? null
                            : () => ref.read(notificationControllerProvider.notifier).markRead(item.id),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _NotificationSkeleton extends StatelessWidget {
  const _NotificationSkeleton();
  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (_, __) => const Card(
          child: SizedBox(height: 84, child: Center(child: LinearProgressIndicator())),
        ),
      );
}
