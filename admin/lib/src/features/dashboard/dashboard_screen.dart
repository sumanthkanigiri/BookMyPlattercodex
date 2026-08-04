import 'package:bookmyplatter_admin/src/features/dashboard/dashboard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(dashboardMetricsProvider);
    final orders = ref.watch(recentAdminOrdersProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardMetricsProvider);
        ref.invalidate(recentAdminOrdersProvider);
        await ref.read(dashboardMetricsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Operations overview', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          metrics.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => _ErrorCard(onRetry: () => ref.invalidate(dashboardMetricsProvider)),
            data: (data) => LayoutBuilder(builder: (context, constraints) {
              final width = constraints.maxWidth > 900 ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2;
              return Wrap(spacing: 16, runSpacing: 16, children: [
                _MetricCard(width: width, label: "Today's orders", value: '${data.todayOrders}', icon: Icons.today),
                _MetricCard(width: width, label: 'Upcoming events', value: '${data.upcomingEvents}', icon: Icons.event_available),
                _MetricCard(width: width, label: 'Customers', value: '${data.customers}', icon: Icons.people_outline),
                _MetricCard(width: width, label: 'Paid revenue', value: NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(data.revenue), icon: Icons.currency_rupee),
              ]);
            }),
          ),
          const SizedBox(height: 28),
          Row(children: [Expanded(child: Text('Recent orders', style: Theme.of(context).textTheme.titleLarge)), TextButton(onPressed: () => context.go('/orders'), child: const Text('View all'))]),
          const SizedBox(height: 8),
          orders.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => _ErrorCard(onRetry: () => ref.invalidate(recentAdminOrdersProvider)),
            data: (items) => items.isEmpty
                ? const Card(child: ListTile(title: Text('No orders yet')))
                : Card(
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(columns: const [DataColumn(label: Text('Customer')), DataColumn(label: Text('Package')), DataColumn(label: Text('Event')), DataColumn(label: Text('Status')), DataColumn(label: Text('Total'))], rows: [
                        for (final order in items)
                          DataRow(cells: [DataCell(Text(order.customer)), DataCell(Text(order.packageName)), DataCell(Text(DateFormat('d MMM, h:mm a').format(order.eventAt))), DataCell(Chip(label: Text(order.status))), DataCell(Text('₹${order.total.toStringAsFixed(0)}'))]),
                      ]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.width, required this.label, required this.value, required this.icon});
  final double width;
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: Card(child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [CircleAvatar(backgroundColor: const Color(0xFFF0E9FC), child: Icon(icon, color: const Color(0xFF3C1285))), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: Theme.of(context).textTheme.headlineSmall), Text(label)]))]))));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(leading: const Icon(Icons.error_outline), title: const Text('Unable to load dashboard data'), trailing: IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh))));
}
