import 'package:bookmyplatter_admin/src/features/events/admin_events_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class AdminEventsScreen extends ConsumerWidget {
  const AdminEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(companyEventsRealtimeProvider, (_, __) {
      ref.invalidate(eventMetricsProvider);
      ref.invalidate(companyEventsProvider);
    });
    final metrics = ref.watch(eventMetricsProvider);
    final events = ref.watch(companyEventsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(eventMetricsProvider);
        ref.invalidate(companyEventsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Company Event Management', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('BookMyPlatter-operated event calendar synchronized from bookings, leads, kitchen, staff and delivery workflows.', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 20),
          metrics.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => _Failure(message: error.toString(), onRetry: () => ref.invalidate(eventMetricsProvider)),
            data: (item) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(label: 'Today', value: item.today, icon: Icons.today_outlined),
                _MetricCard(label: 'Tomorrow', value: item.tomorrow, icon: Icons.next_plan_outlined),
                _MetricCard(label: 'Upcoming', value: item.upcoming, icon: Icons.event_available_outlined),
                _MetricCard(label: 'Completed', value: item.completed, icon: Icons.verified_outlined),
                _MetricCard(label: 'Cancelled', value: item.cancelled, icon: Icons.cancel_outlined),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Unified Event Calendar', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          events.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => _Failure(message: error.toString(), onRetry: () => ref.invalidate(companyEventsProvider)),
            data: (items) => items.isEmpty ? const _EmptyEvents() : Column(children: [for (final item in items) _EventTile(item: item)]),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon});
  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 180,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [CircleAvatar(child: Icon(icon)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label), Text('$value', style: Theme.of(context).textTheme.headlineSmall)]))]),
          ),
        ),
      );
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.item});
  final CompanyEventSummary item;

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('EEE, d MMM • h:mm a');
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.event_note_outlined),
        title: Text('${item.eventName.replaceAll('_', ' ')} • ${item.eventNumber}'),
        subtitle: Text('${format.format(item.eventAt)} • ${item.guestCount} guests • ${item.venueAddress}'),
        trailing: Chip(label: Text(item.status.replaceAll('_', ' '))),
        childrenPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('Type: ${item.eventType.replaceAll('_', ' ')}')),
              Chip(label: Text('Kitchen: ${item.kitchenStatus.replaceAll('_', ' ')}')),
              Chip(label: Text('Staff: ${item.staffStatus.replaceAll('_', ' ')}')),
              Chip(label: Text('Delivery: ${item.deliveryStatus.replaceAll('_', ' ')}')),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyEvents extends StatelessWidget {
  const _EmptyEvents();
  @override
  Widget build(BuildContext context) => const Card(child: ListTile(leading: Icon(Icons.event_busy_outlined), title: Text('No company events found'), subtitle: Text('Confirmed bookings will synchronize into the event calendar.')));
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(leading: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error), title: Text(message), trailing: IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh))));
}
