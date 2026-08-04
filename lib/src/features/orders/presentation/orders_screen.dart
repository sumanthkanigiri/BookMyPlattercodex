import 'package:bookmyplatter/src/features/orders/application/order_controller.dart';
import 'package:bookmyplatter/src/features/orders/domain/order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(orderControllerProvider);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Orders'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Today'),
              Tab(text: 'Upcoming'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
        ),
        body: orders.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => ref.read(orderControllerProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (items) => TabBarView(
            children: [
              _OrderList(orders: items.where((order) => order.isToday && order.isActive).toList()),
              _OrderList(orders: items.where((order) => order.isUpcoming).toList()),
              _OrderList(orders: items.where((order) => order.status == 'delivered').toList()),
              _OrderList(orders: items.where((order) => {'cancelled', 'refunded'}.contains(order.status)).toList()),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderList extends ConsumerWidget {
  const _OrderList({required this.orders});

  final List<PlatterOrder> orders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orders.isEmpty) return const Center(child: Text('No orders in this section'));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Card(
          child: ExpansionTile(
            leading: const Icon(Icons.receipt_long),
            title: Text(order.packageName),
            subtitle: Text('${_label(order.status)} • ${DateFormat('d MMM, h:mm a').format(order.eventAt)}'),
            trailing: Text('₹${order.total.toStringAsFixed(0)}'),
            children: [
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('View booking and tracking'),
                onTap: () => context.go('/order/${order.id}'),
              ),
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: Text('${order.guestCount} guests'),
                subtitle: Text(order.deliveryAddress),
              ),
              for (final event in order.events)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(event.message),
                  subtitle: Text(DateFormat('d MMM, h:mm a').format(event.createdAt)),
                ),
              if (const {'placed', 'confirmed'}.contains(order.status))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: OutlinedButton.icon(
                    onPressed: () => _cancel(context, ref, order),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel order'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _label(String status) => status
      .split('_')
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  Future<void> _cancel(BuildContext context, WidgetRef ref, PlatterOrder order) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel order?'),
        content: TextField(
          controller: controller,
          maxLength: 250,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep order')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel order')),
        ],
      ),
    );
    final reason = controller.text.trim();
    controller.dispose();
    if (confirmed != true || !context.mounted) return;
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a cancellation reason')));
      return;
    }
    try {
      await ref.read(orderControllerProvider.notifier).cancel(order.id, reason);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This order can no longer be cancelled')),
        );
      }
    }
  }
}
