import 'package:bookmyplatter_admin/src/features/dashboard/dashboard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(ownerDashboardRealtimeProvider, (_, __) {
      ref.invalidate(ownerDashboardSnapshotProvider);
      ref.invalidate(dashboardMetricsProvider);
      ref.invalidate(recentAdminOrdersProvider);
    });
    final ownerSnapshot = ref.watch(ownerDashboardSnapshotProvider);
    final metrics = ref.watch(dashboardMetricsProvider);
    final orders = ref.watch(recentAdminOrdersProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(ownerDashboardSnapshotProvider);
        ref.invalidate(dashboardMetricsProvider);
        ref.invalidate(recentAdminOrdersProvider);
        await ref.read(dashboardMetricsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Owner dashboard', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text('Realtime revenue, conversion, customer, website, app, finance, staff and AI health for BookMyPlatter owned operations.', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 20),
          ownerSnapshot.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => _ErrorCard(onRetry: () => ref.invalidate(ownerDashboardSnapshotProvider)),
            data: (snapshot) => _OwnerSnapshotView(snapshot: snapshot),
          ),
          const SizedBox(height: 28),
          Text('Operations overview', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
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


class _OwnerSnapshotView extends StatelessWidget {
  const _OwnerSnapshotView({required this.snapshot});
  final OwnerDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth > 1100 ? (constraints.maxWidth - 48) / 4 : constraints.maxWidth > 700 ? (constraints.maxWidth - 32) / 3 : (constraints.maxWidth - 16) / 2;
        return Wrap(spacing: 16, runSpacing: 16, children: [
          _MetricCard(width: width, label: "Today's revenue", value: currency.format(metricDouble(snapshot.owner, 'today_revenue')), icon: Icons.currency_rupee),
          _MetricCard(width: width, label: "Today's bookings", value: metricText(snapshot.owner, 'today_bookings'), icon: Icons.event_available),
          _MetricCard(width: width, label: "Today's enquiries", value: metricText(snapshot.owner, 'today_enquiries'), icon: Icons.support_agent),
          _MetricCard(width: width, label: 'Profit today', value: currency.format(metricDouble(snapshot.owner, 'profit_today')), icon: Icons.trending_up),
          _MetricCard(width: width, label: 'Pending payments', value: currency.format(metricDouble(snapshot.owner, 'pending_payments')), icon: Icons.pending_actions),
          _MetricCard(width: width, label: 'Monthly revenue', value: currency.format(metricDouble(snapshot.owner, 'monthly_revenue')), icon: Icons.calendar_month),
          _MetricCard(width: width, label: 'Yearly revenue', value: currency.format(metricDouble(snapshot.owner, 'yearly_revenue')), icon: Icons.stacked_line_chart),
          _MetricCard(width: width, label: 'Live visitors', value: metricText(snapshot.website, 'live_visitors'), icon: Icons.visibility),
        ]);
      }),
      const SizedBox(height: 20),
      Wrap(spacing: 16, runSpacing: 16, children: [
        _AnalyticsPanel(title: 'Sales analytics', icon: Icons.query_stats, items: {
          'Lead conversion': "${metricText(snapshot.sales, 'lead_conversion_percent')}%",
          'Checkout conversion': "${metricText(snapshot.sales, 'checkout_conversion_percent')}%",
          'WhatsApp clicks': metricText(snapshot.sales, 'whatsapp_clicks'),
          'Call clicks': metricText(snapshot.sales, 'call_clicks'),
        }),
        _AnalyticsPanel(title: 'Customer analytics', icon: Icons.people_alt_outlined, items: {
          'New customers': metricText(snapshot.customer, 'new_customers'),
          'Returning customers': metricText(snapshot.customer, 'returning_customers'),
          'Average booking': currency.format(metricDouble(snapshot.customer, 'average_booking_value')),
          'Top location': ((snapshot.customer['top_location'] as Map?)?['location'] ?? 'Not captured').toString(),
        }),
        _AnalyticsPanel(title: 'App & website', icon: Icons.devices, items: {
          'Page views': metricText(snapshot.website, 'page_views'),
          'Daily active users': metricText(snapshot.app, 'daily_active_users'),
          'App opens': metricText(snapshot.app, 'app_opens'),
          'Cart events': metricText(snapshot.app, 'cart_events'),
        }),
        _AnalyticsPanel(title: 'Finance', icon: Icons.account_balance_wallet_outlined, items: {
          'Revenue': currency.format(metricDouble(snapshot.finance, 'revenue')),
          'Expenses': currency.format(metricDouble(snapshot.finance, 'expenses')),
          'Profit': currency.format(metricDouble(snapshot.finance, 'profit')),
          'Outstanding': currency.format(metricDouble(snapshot.finance, 'outstanding_payments')),
        }),
        _AnalyticsPanel(title: 'Staff operations', icon: Icons.badge_outlined, items: {
          'Attendance': metricText(snapshot.staff, 'attendance_today'),
          'Kitchen completed': metricText(snapshot.staff, 'kitchen_completed'),
          'Deliveries completed': metricText(snapshot.staff, 'delivery_completed'),
        }),
        _AnalyticsPanel(title: 'AI reports', icon: Icons.auto_awesome, items: {
          'Revenue forecast': currency.format(metricDouble(snapshot.ai, 'revenue_forecast')),
          'Demand forecast': metricText(snapshot.ai, 'demand_forecast'),
          'Health': metricText(snapshot.ai, 'business_health'),
          'Suggestion': metricText(snapshot.ai, 'marketing_suggestion'),
        }),
      ]),
    ]);
  }
}

class _AnalyticsPanel extends StatelessWidget {
  const _AnalyticsPanel({required this.title, required this.icon, required this.items});
  final String title;
  final IconData icon;
  final Map<String, String> items;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 340,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(icon, color: const Color(0xFF3C1285)), const SizedBox(width: 8), Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)))]),
              const SizedBox(height: 12),
              for (final item in items.entries) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(item.key)), const SizedBox(width: 8), Flexible(child: Text(item.value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700)))])),
            ]),
          ),
        ),
      );
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
