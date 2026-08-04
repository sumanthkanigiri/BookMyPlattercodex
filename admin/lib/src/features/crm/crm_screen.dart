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
    ref.listen(customerActivityEventsProvider, (_, __) {
      ref.invalidate(customerActivityProvider);
      ref.invalidate(enterpriseCrmAnalyticsProvider);
    });
    ref.listen(communicationLogEventsProvider, (_, __) {
      ref.invalidate(communicationLogsProvider);
      ref.invalidate(enterpriseCrmAnalyticsProvider);
    });
    final metrics = ref.watch(crmMetricsProvider);
    final leads = ref.watch(crmLeadsProvider);
    final templates = ref.watch(notificationTemplatesProvider);
    final activity = ref.watch(customerActivityProvider);
    final funnel = ref.watch(crmFunnelProvider);
    final analytics = ref.watch(enterpriseCrmAnalyticsProvider);
    final communications = ref.watch(communicationLogsProvider);
    final campaigns = ref.watch(crmCampaignsProvider);
    final aiAssets = ref.watch(aiMarketingAssetsProvider);
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
            Text('Enterprise AI CRM Intelligence', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            analytics.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _Failure(message: error.toString(), onRetry: () => ref.invalidate(enterpriseCrmAnalyticsProvider)),
              data: (item) => _AnalyticsPanel(item: item),
            ),
            const SizedBox(height: 16),
            funnel.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _Failure(message: error.toString(), onRetry: () => ref.invalidate(crmFunnelProvider)),
              data: (items) => _FunnelPanel(items: items),
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
            Text('Live Customer Activity', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            activity.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _Failure(message: error.toString(), onRetry: () => ref.invalidate(customerActivityProvider)),
              data: (items) => items.isEmpty
                  ? const Card(child: ListTile(leading: Icon(Icons.timeline), title: Text('No customer activity captured yet')))
                  : Column(children: [for (final item in items) _ActivityTile(item: item)]),
            ),
            const SizedBox(height: 24),
            Text('Communication Center', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            communications.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _Failure(message: error.toString(), onRetry: () => ref.invalidate(communicationLogsProvider)),
              data: (items) => _CommunicationPanel(items: items),
            ),
            const SizedBox(height: 24),
            Text('Campaign Manager', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            campaigns.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _Failure(message: error.toString(), onRetry: () => ref.invalidate(crmCampaignsProvider)),
              data: (items) => _CampaignPanel(items: items),
            ),
            const SizedBox(height: 24),
            Text('AI Marketing Queue', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            aiAssets.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _Failure(message: error.toString(), onRetry: () => ref.invalidate(aiMarketingAssetsProvider)),
              data: (items) => _AiMarketingPanel(items: items),
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
          '${lead.guestCount ?? 0} guests • $followUp\n'
          'Score ${lead.leadScore} • ₹${lead.expectedRevenue.toStringAsFixed(0)} expected • '
          '${lead.probability}% probability • P${lead.priority}\n${lead.notes}',
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

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});
  final CustomerActivityEvent item;

  @override
  Widget build(BuildContext context) {
    final detail = item.searchQuery.isNotEmpty
        ? 'Search: ${item.searchQuery}'
        : item.pagePath.isNotEmpty
            ? item.pagePath
            : item.customerId.isNotEmpty
                ? 'Customer ${item.customerId}'
                : 'Anonymous visitor';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.insights),
        title: Text(item.activityType.replaceAll('_', ' ')),
        subtitle: Text(detail),
        trailing: Text(DateFormat('d MMM, h:mm a').format(item.occurredAt)),
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


class _AnalyticsPanel extends StatelessWidget {
  const _AnalyticsPanel({required this.item});
  final EnterpriseCrmAnalytics item;

  @override
  Widget build(BuildContext context) {
    final percent = NumberFormat.percentPattern();
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MetricCard(label: 'Total Leads', value: item.totalLeads, icon: Icons.groups_2_outlined),
        _MetricCard(label: 'Website Visits', value: item.websiteVisits, icon: Icons.language_outlined),
        _MetricCard(label: 'App Opens', value: item.appOpens, icon: Icons.phone_android_outlined),
        SizedBox(width: 220, child: Card(child: ListTile(leading: const Icon(Icons.call_split_outlined), title: const Text('Conversion'), subtitle: Text(percent.format(item.conversionRate))))),
        SizedBox(width: 220, child: Card(child: ListTile(leading: const Icon(Icons.sms_outlined), title: const Text('SMS Delivery'), subtitle: Text(percent.format(item.smsDeliveryRate))))),
        SizedBox(width: 220, child: Card(child: ListTile(leading: const Icon(Icons.chat_outlined), title: const Text('WhatsApp Delivery'), subtitle: Text(percent.format(item.whatsappDeliveryRate))))),
      ],
    );
  }
}

class _FunnelPanel extends StatelessWidget {
  const _FunnelPanel({required this.items});
  final List<CrmFunnelStage> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Card(child: ListTile(leading: Icon(Icons.filter_alt_outlined), title: Text('No funnel data available')));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final stage in items)
              Chip(label: Text('${stage.status.replaceAll('_', ' ')} • ${stage.count} • ₹${stage.expectedRevenue.toStringAsFixed(0)}')),
          ],
        ),
      ),
    );
  }
}

class _CommunicationPanel extends StatelessWidget {
  const _CommunicationPanel({required this.items});
  final List<CommunicationLogEntry> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Card(child: ListTile(leading: Icon(Icons.mark_email_read_outlined), title: Text('No communication logs yet')));
    return Column(children: [for (final item in items.take(8)) _CommunicationTile(item: item)]);
  }
}

class _CommunicationTile extends StatelessWidget {
  const _CommunicationTile({required this.item});
  final CommunicationLogEntry item;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(item.channel == 'whatsapp' ? Icons.chat_outlined : item.channel == 'sms' ? Icons.sms_outlined : Icons.notifications_outlined),
          title: Text('${item.channel.toUpperCase()} • ${item.templateKey}'),
          subtitle: Text(item.recipient.isEmpty ? 'Recipient pending' : item.recipient),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text(item.status), Text(DateFormat('d MMM, h:mm a').format(item.createdAt))]),
        ),
      );
}

class _CampaignPanel extends StatelessWidget {
  const _CampaignPanel({required this.items});
  final List<CrmCampaignSnapshot> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Card(child: ListTile(leading: Icon(Icons.campaign_outlined), title: Text('No campaigns scheduled')));
    return Column(children: [
      for (final item in items.take(6))
        Card(child: ListTile(leading: const Icon(Icons.campaign_outlined), title: Text(item.name), subtitle: Text('${item.channel} • ${item.status}'), trailing: Text('${item.delivered}/${item.sent} delivered'))),
    ]);
  }
}

class _AiMarketingPanel extends StatelessWidget {
  const _AiMarketingPanel({required this.items});
  final List<AiMarketingAssetSummary> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Card(child: ListTile(leading: Icon(Icons.auto_awesome_outlined), title: Text('No AI marketing assets queued')));
    return Column(children: [
      for (final item in items.take(6))
        Card(child: ListTile(leading: const Icon(Icons.auto_awesome_outlined), title: Text(item.title), subtitle: Text('${item.assetType.replaceAll('_', ' ')} • ${item.status}'), trailing: Text(item.publishAt == null ? 'Manual publish' : DateFormat('d MMM').format(item.publishAt!)))),
    ]);
  }
}
