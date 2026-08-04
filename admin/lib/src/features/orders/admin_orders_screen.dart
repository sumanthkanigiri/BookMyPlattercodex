import 'dart:async';

import 'package:bookmyplatter_admin/src/core/admin_session.dart';
import 'package:bookmyplatter_admin/src/features/dashboard/dashboard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final adminOrdersProvider = StreamProvider<List<AdminOrder>>((ref) {
  final client = ref.watch(supabaseProvider);
  final controller = StreamController<List<AdminOrder>>();
  Future<void> load() async {
    try {
      final rows = await client
          .from('orders')
          .select('id,event_at,status,grand_total,profiles!orders_customer_id_fkey(full_name),packages(name)')
          .order('event_at');
      controller.add([for (final row in rows) AdminOrder.fromMap(row)]);
    } catch (error, stackTrace) {
      controller.addError(error, stackTrace);
    }
  }
  final channel = client.channel('admin-orders').onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'orders',
        callback: (_) => load(),
      ).subscribe();
  load();
  ref.onDispose(() {
    client.removeChannel(channel);
    controller.close();
  });
  return controller.stream;
});

class AdminOrdersScreen extends ConsumerWidget {
  const AdminOrdersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(adminOrdersProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order management', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Expanded(
            child: orders.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: FilledButton.icon(onPressed: () => ref.invalidate(adminOrdersProvider), icon: const Icon(Icons.refresh), label: const Text('Retry'))),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('No orders found'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final order = items[index];
                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
                            title: Text('${order.customer} • ${order.packageName}'),
                            subtitle: Text('${DateFormat('EEE, d MMM yyyy • h:mm a').format(order.eventAt)}\n₹${order.total.toStringAsFixed(0)}'),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(label: Text(order.status.replaceAll('_', ' '))),
                                const SizedBox(width: 8),
                                PopupMenuButton<String>(
                                  tooltip: 'Change order status',
                                  onSelected: (status) => _transition(context, ref, order.id, status),
                                  itemBuilder: (_) => [
                                    for (final entry in _transitions(order.status).entries)
                                      PopupMenuItem(value: entry.key, child: Text(entry.value)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, String> _transitions(String status) => switch (status) {
        'placed' => const {'confirmed': 'Accept order', 'cancelled': 'Reject order'},
        'confirmed' => const {'preparing': 'Start preparation', 'cancelled': 'Cancel order'},
        'preparing' => const {'packing': 'Start packing', 'cancelled': 'Cancel order'},
        'packing' => const {'out_for_delivery': 'Dispatch team', 'cancelled': 'Cancel order'},
        'out_for_delivery' => const {'arrived_at_venue': 'Mark arrived at venue'},
        'arrived_at_venue' => const {'event_started': 'Start event'},
        'event_started' => const {'delivered': 'Complete event'},
        _ => const {},
      };

  Future<void> _transition(BuildContext context, WidgetRef ref, String orderId, String status) async {
    try {
      final response = await ref.read(supabaseProvider).functions.invoke('order-transition', body: {'orderId': orderId, 'status': status});
      if (response.status < 200 || response.status >= 300) throw StateError('Order update was rejected');
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order status updated')));
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}
