import 'package:bookmyplatter_admin/src/features/crm/crm_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class CrmScreen extends ConsumerWidget {
  const CrmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(crmLeadEventsProvider, (_, __) {
      ref
        ..invalidate(crmMetricsProvider)
        ..invalidate(crmLeadsProvider);
    });
    final metrics = ref.watch(crmMetricsProvider);
    final leads = ref.watch(crmLeadsProvider);
    final templates = ref.watch(notificationTemplatesProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(crmMetricsProvider)
            ..invalidate(crmLeadsProvider);
          await ref.read(crmLeadsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('CRM & Follow-up Automation', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            metrics.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _Failure(message: error.toString(), onRetry: () => ref.invalidate(crmMetricsProvider)),
              data: (item) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricCard(label: 'Today\'s Leads', value: item.todayLeads, icon: Icons.person_add_alt),
                  _MetricCard(label: 'Pending Leads', value: item.pendingLeads, icon: Icons.pending_actions),
                  _MetricCard(label: 'Converted', value: item.convertedLeads, icon: Icons.verified),
                  _MetricCard(label: 'Lost', value: item.lostLeads, icon: Icons.remove_circle_outline),
                  _MetricCard(label: 'Abandoned Checkout', value: item.abandonedCheckouts, icon: Icons.shopping_cart_checkout),
                  _MetricCard(label: 'Due Follow-ups', value: item.pendingFollowUps, icon: Icons.schedule),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Lead Queue', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            leads.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _Failure(message: error.toString(), onRetry: () => ref.invalidate(crmLeadsProvider)),
              data: (items) => items.isEmpty
                  ? const Card(child: ListTile(leading: Icon(Icons.inbox_outlined), title: Text('No leads yet')))
                  : Column(children: [for (final lead in items) _LeadTile(lead: lead)]),
            ),
            const SizedBox(height: 24),
            Text('Notification Templates', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            templates.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _Failure(message: error.toString(), onRetry: () => ref.invalidate(notificationTemplatesProvider)),
              data: (items) => items.isEmpty
                  ? const Card(child: ListTile(leading: Icon(Icons.sms_outlined), title: Text('No notification templates configured')))
                  : Column(children: [for (final item in items) _TemplateTile(item: item, ref: ref)]),
            ),
          ],
        ),
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
        width: 220,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(child: Icon(icon)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label),
                      Text('$value', style: Theme.of(context).textTheme.headlineSmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _LeadTile extends StatelessWidget {
  const _LeadTile({required this.lead});
  final CrmLead lead;

  @override
  Widget build(BuildContext context) {
    final followUp = lead.nextFollowUpAt == null
        ? 'No follow-up scheduled'
        : 'Next: ${DateFormat('d MMM, h:mm a').format(lead.nextFollowUpAt!)}';
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(lead.source.characters.first.toUpperCase())),
        title: Text(lead.customerName.isEmpty ? lead.mobile : lead.customerName),
        subtitle: Text(
          '${lead.eventType.replaceAll('_', ' ')} • '
          '${lead.guestCount ?? 0} guests • $followUp\n${lead.notes}',
        ),
        isThreeLine: true,
        trailing: Wrap(
          spacing: 8,
          children: [
            Chip(label: Text(lead.status.replaceAll('_', ' '))),
            Chip(label: Text(lead.bookingStatus.replaceAll('_', ' '))),
          ],
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          title: Text(message),
          trailing: IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh)),
        ),
      );
}


class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.item, required this.ref});
  final NotificationTemplateConfig item;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final template = item.channel == 'sms'
        ? 'Message ID ${item.smsMessageId}'
        : '${item.whatsappTemplateName} • ${item.whatsappTemplateId}';
    return Card(
      child: ListTile(
        leading: Icon(item.channel == 'sms' ? Icons.sms_outlined : Icons.chat_outlined),
        title: Text(item.feature),
        subtitle: Text('${item.templateKey} • $template'),
        trailing: Switch(
          value: item.enabled,
          onChanged: (enabled) async {
            await ref.read(notificationTemplateRepositoryProvider).setEnabled(
                  templateKey: item.templateKey,
                  channel: item.channel,
                  enabled: enabled,
                );
            ref.invalidate(notificationTemplatesProvider);
          },
        ),
      ),
    );
  }
}
