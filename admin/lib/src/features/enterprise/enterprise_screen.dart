import 'package:bookmyplatter_admin/src/features/enterprise/enterprise_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class EnterpriseScreen extends ConsumerWidget {
  const EnterpriseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(enterpriseRealtimeProvider, (_, __) {
      ref.invalidate(enterpriseDashboardProvider);
      ref.invalidate(enterpriseCalendarProvider);
      ref.invalidate(enterpriseKitchenProvider);
      ref.invalidate(enterpriseTasksProvider);
      ref.invalidate(enterpriseFinanceProvider);
    });
    final metrics = ref.watch(enterpriseDashboardProvider);
    final calendar = ref.watch(enterpriseCalendarProvider);
    final kitchen = ref.watch(enterpriseKitchenProvider);
    final tasks = ref.watch(enterpriseTasksProvider);
    final finance = ref.watch(enterpriseFinanceProvider);
    final cms = ref.watch(enterpriseCmsProvider);
    final marketing = ref.watch(enterpriseMarketingProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(enterpriseDashboardProvider);
        ref.invalidate(enterpriseCalendarProvider);
        ref.invalidate(enterpriseKitchenProvider);
        ref.invalidate(enterpriseTasksProvider);
        ref.invalidate(enterpriseFinanceProvider);
        ref.invalidate(enterpriseCmsProvider);
        ref.invalidate(enterpriseMarketingProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _Header(onRefresh: () => ref.invalidate(enterpriseDashboardProvider)),
          const SizedBox(height: 20),
          metrics.when(
            loading: () => const _MetricSkeletonGrid(),
            error: (error, _) => _ErrorCard(title: 'Enterprise dashboard unavailable', message: error.toString(), onRetry: () => ref.invalidate(enterpriseDashboardProvider)),
            data: (data) => _MetricGrid(metrics: data),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1100;
              final panels = [
                _AsyncPanel<List<EnterpriseCalendarEvent>>(
                  title: 'Event calendar',
                  icon: Icons.calendar_month_outlined,
                  value: calendar,
                  onRetry: () => ref.invalidate(enterpriseCalendarProvider),
                  builder: (events) => _CalendarList(events: events),
                ),
                _AsyncPanel<List<EnterpriseKitchenItem>>(
                  title: 'Kitchen command',
                  icon: Icons.soup_kitchen_outlined,
                  value: kitchen,
                  onRetry: () => ref.invalidate(enterpriseKitchenProvider),
                  builder: (items) => _KitchenList(items: items),
                ),
              ];
              if (!wide) return Column(children: panels.map((panel) => Padding(padding: const EdgeInsets.only(bottom: 16), child: panel)).toList());
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final panel in panels) Expanded(child: Padding(padding: const EdgeInsets.only(right: 16), child: panel))]);
            },
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1200 ? 3 : constraints.maxWidth >= 820 ? 2 : 1;
              final panels = <Widget>[
                _AsyncPanel<List<EnterpriseStaffTask>>(
                  title: 'Staff tasks & reminders',
                  icon: Icons.task_alt_outlined,
                  value: tasks,
                  onRetry: () => ref.invalidate(enterpriseTasksProvider),
                  builder: (items) => _TaskList(tasks: items),
                ),
                _AsyncPanel<EnterpriseFinanceSummary>(
                  title: 'Finance snapshot',
                  icon: Icons.account_balance_wallet_outlined,
                  value: finance,
                  onRetry: () => ref.invalidate(enterpriseFinanceProvider),
                  builder: (summary) => _FinanceSummaryView(summary: summary),
                ),
                _AsyncPanel<EnterpriseCmsSummary>(
                  title: 'Website CMS',
                  icon: Icons.language_outlined,
                  value: cms,
                  onRetry: () => ref.invalidate(enterpriseCmsProvider),
                  builder: (summary) => _CmsSummaryView(summary: summary),
                ),
                _AsyncPanel<EnterpriseMarketingSummary>(
                  title: 'Marketing automation',
                  icon: Icons.campaign_outlined,
                  value: marketing,
                  onRetry: () => ref.invalidate(enterpriseMarketingProvider),
                  builder: (summary) => _MarketingSummaryView(summary: summary),
                ),
                const _StaticCapabilityPanel(
                  title: 'Security & audit',
                  icon: Icons.verified_user_outlined,
                  capabilities: ['Role based access', 'Admin audit logs', 'RLS protected ERP tables', 'Realtime alert streams'],
                ),
                const _StaticCapabilityPanel(
                  title: 'Reports',
                  icon: Icons.insights_outlined,
                  capabilities: ['Revenue reports', 'Lead conversion', 'Package performance', 'SMS & WhatsApp delivery'],
                ),
              ];
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final panel in panels)
                    SizedBox(width: columns == 1 ? constraints.maxWidth : (constraints.maxWidth - (16 * (columns - 1))) / columns, child: panel),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF3C1285), Color(0xFF6D35D5)]),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Enterprise ERP Command Center', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Realtime CRM, orders, finance, kitchen, staff, CMS and marketing intelligence from Supabase.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xDBFFFFFF))),
                ],
              ),
            ),
            FilledButton.tonalIcon(onPressed: onRefresh, icon: const Icon(Icons.sync), label: const Text('Refresh')),
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});
  final EnterpriseDashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final cards = [
      _Metric('Today\'s Orders', metrics.todayOrders.toString(), Icons.receipt_long_outlined),
      _Metric('Today\'s Revenue', money.format(metrics.todayRevenue), Icons.currency_rupee_outlined),
      _Metric('Today\'s Enquiries', metrics.todayEnquiries.toString(), Icons.support_agent_outlined),
      _Metric('Today\'s Visitors', metrics.todayVisitors.toString(), Icons.visibility_outlined),
      _Metric('Live Visitors', metrics.activeUsers.toString(), Icons.radar_outlined),
      _Metric('Pending Payments', metrics.pendingPayments.toString(), Icons.payments_outlined),
      _Metric('Pending Follow-ups', metrics.pendingFollowUps.toString(), Icons.alarm_outlined),
      _Metric('Checkout Recovery', metrics.checkoutRecovery.toString(), Icons.shopping_cart_checkout_outlined),
      _Metric('Food Tasting', metrics.foodTasting.toString(), Icons.restaurant_menu_outlined),
      _Metric('Today\'s Deliveries', metrics.todayDeliveries.toString(), Icons.delivery_dining_outlined),
      _Metric('Kitchen Queue', metrics.kitchenQueue.toString(), Icons.soup_kitchen_outlined),
      _Metric('Upcoming Events', metrics.upcomingEvents.toString(), Icons.event_available_outlined),
      _Metric('Tomorrow Events', metrics.tomorrowEvents.toString(), Icons.next_plan_outlined),
      _Metric('Open Tasks', metrics.openTasks.toString(), Icons.assignment_outlined),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 1200 ? (constraints.maxWidth - 48) / 4 : constraints.maxWidth >= 760 ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth >= 520 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
        return Wrap(spacing: 16, runSpacing: 16, children: [for (final card in cards) SizedBox(width: width, child: _MetricCard(metric: card))]);
      },
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});
  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: Theme.of(context).colorScheme.secondaryContainer, child: Icon(metric.icon, color: Theme.of(context).colorScheme.onSecondaryContainer)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(metric.value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), Text(metric.label, overflow: TextOverflow.ellipsis)])),
          ],
        ),
      ),
    );
  }
}

class _MetricSkeletonGrid extends StatelessWidget {
  const _MetricSkeletonGrid();
  @override
  Widget build(BuildContext context) => Wrap(spacing: 16, runSpacing: 16, children: [for (var i = 0; i < 8; i++) const SizedBox(width: 240, height: 92, child: Card(child: Center(child: CircularProgressIndicator()))) ]);
}

class _AsyncPanel<T> extends StatelessWidget {
  const _AsyncPanel({required this.title, required this.icon, required this.value, required this.builder, required this.onRetry});
  final String title;
  final IconData icon;
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)))]),
            const SizedBox(height: 14),
            value.when(loading: () => const SizedBox(height: 140, child: Center(child: CircularProgressIndicator())), error: (error, _) => _ErrorCard(title: title, message: error.toString(), onRetry: onRetry), data: builder),
          ],
        ),
      ),
    );
  }
}

class _CalendarList extends StatelessWidget {
  const _CalendarList({required this.events});
  final List<EnterpriseCalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const _EmptyState(message: 'No upcoming events found in Supabase.');
    final format = DateFormat('EEE, d MMM • h:mm a');
    return Column(children: [
      for (final event in events.take(8))
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_note_outlined),
          title: Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${format.format(event.eventAt)} • ${event.guests} guests • ${event.venue}'),
          trailing: Chip(label: Text(event.status)),
        ),
    ]);
  }
}

class _KitchenList extends StatelessWidget {
  const _KitchenList({required this.items});
  final List<EnterpriseKitchenItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyState(message: 'Kitchen queue is empty. Confirmed bookings will appear here.');
    final format = DateFormat('d MMM, h:mm a');
    return Column(children: [
      for (final item in items.take(8))
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.restaurant_outlined),
          title: Text('${item.station} • ${item.status}'),
          subtitle: Text('Order ${item.orderId.substring(0, 8)} • Chef ${item.chefName}'),
          trailing: Text(item.readyBy == null ? 'Ready time open' : format.format(item.readyBy!)),
        ),
    ]);
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.tasks});
  final List<EnterpriseStaffTask> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const _EmptyState(message: 'No open staff tasks or reminders.');
    final format = DateFormat('d MMM, h:mm a');
    return Column(children: [
      for (final task in tasks.take(6))
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(task.priority == 'urgent' ? Icons.priority_high : Icons.task_outlined),
          title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${task.module} • ${task.assignee}'),
          trailing: Text(task.dueAt == null ? task.status : format.format(task.dueAt!)),
        ),
    ]);
  }
}

class _FinanceSummaryView extends StatelessWidget {
  const _FinanceSummaryView({required this.summary});
  final EnterpriseFinanceSummary summary;
  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return Column(children: [
      _KeyValue(label: 'Monthly revenue', value: money.format(summary.revenue)),
      _KeyValue(label: 'Expenses', value: money.format(summary.expenses)),
      _KeyValue(label: 'Purchase orders', value: money.format(summary.purchaseOrders)),
      _KeyValue(label: 'Pending vendor payments', value: summary.pendingVendorPayments.toString()),
      _KeyValue(label: 'Projected profit', value: money.format(summary.profit)),
    ]);
  }
}

class _CmsSummaryView extends StatelessWidget {
  const _CmsSummaryView({required this.summary});
  final EnterpriseCmsSummary summary;
  @override
  Widget build(BuildContext context) => Column(children: [_KeyValue(label: 'Banners', value: '${summary.banners}'), _KeyValue(label: 'Blogs', value: '${summary.blogs}'), _KeyValue(label: 'FAQ entries', value: '${summary.faqs}'), _KeyValue(label: 'Testimonials', value: '${summary.testimonials}'), _KeyValue(label: 'SEO pages', value: '${summary.seoPages}')]);
}

class _MarketingSummaryView extends StatelessWidget {
  const _MarketingSummaryView({required this.summary});
  final EnterpriseMarketingSummary summary;
  @override
  Widget build(BuildContext context) => Column(children: [_KeyValue(label: 'Running campaigns', value: '${summary.runningCampaigns}'), _KeyValue(label: 'Scheduled campaigns', value: '${summary.scheduledCampaigns}'), _KeyValue(label: 'Messages sent', value: '${summary.sent}'), _KeyValue(label: 'Delivered', value: '${summary.delivered}'), _KeyValue(label: 'Failed', value: '${summary.failed}')]);
}

class _StaticCapabilityPanel extends StatelessWidget {
  const _StaticCapabilityPanel({required this.title, required this.icon, required this.capabilities});
  final String title;
  final IconData icon;
  final List<String> capabilities;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)))]),
          const SizedBox(height: 12),
          for (final capability in capabilities) ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.check_circle_outline), title: Text(capability)),
        ]),
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.w800))]));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text(message, textAlign: TextAlign.center)));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.title, required this.message, required this.onRetry});
  final String title;
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer, fontWeight: FontWeight.w800)), const SizedBox(height: 8), Text(message, maxLines: 4, overflow: TextOverflow.ellipsis), const SizedBox(height: 12), OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry'))]),
        ),
      );
}
