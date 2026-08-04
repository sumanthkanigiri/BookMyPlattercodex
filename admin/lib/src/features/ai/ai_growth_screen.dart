import 'package:bookmyplatter_admin/src/features/ai/ai_growth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class AiGrowthScreen extends ConsumerWidget {
  const AiGrowthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(aiGrowthRealtimeProvider, (_, __) {
      ref.invalidate(aiGrowthSummaryProvider);
      ref.invalidate(aiContentJobsProvider);
    });
    final summary = ref.watch(aiGrowthSummaryProvider);
    final jobs = ref.watch(aiContentJobsProvider);
    final drafts = ref.watch(aiMarketingDraftsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(aiGrowthSummaryProvider);
        ref.invalidate(aiContentJobsProvider);
        ref.invalidate(aiMarketingDraftsProvider);
      },
      child: ListView(padding: const EdgeInsets.all(24), children: [
        Text('AI Growth Center', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('AI assistant, SEO blog generation, review moderation, personalized offers and owned-channel marketing automation.', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 20),
        summary.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => _Failure(message: error.toString(), onRetry: () => ref.invalidate(aiGrowthSummaryProvider)),
          data: (item) => Wrap(spacing: 12, runSpacing: 12, children: [
            _MetricCard(label: 'Blog jobs', value: item.blogJobs, icon: Icons.article_outlined),
            _MetricCard(label: 'Campaigns', value: item.marketingDrafts, icon: Icons.campaign_outlined),
            _MetricCard(label: 'AI chats', value: item.assistantThreads, icon: Icons.auto_awesome),
            _MetricCard(label: 'Reviews', value: item.reviewModeration, icon: Icons.rate_review_outlined),
          ]),
        ),
        const SizedBox(height: 24),
        _Section(title: 'SEO content pipeline', child: jobs.when(loading: () => const LinearProgressIndicator(), error: (error, _) => _Failure(message: error.toString(), onRetry: () => ref.invalidate(aiContentJobsProvider)), data: (items) => items.isEmpty ? const _Empty(message: 'No AI content jobs are queued.') : Column(children: [for (final item in items) _ContentJobTile(item: item)]))),
        const SizedBox(height: 24),
        _Section(title: 'Marketing campaign drafts', child: drafts.when(loading: () => const LinearProgressIndicator(), error: (error, _) => _Failure(message: error.toString(), onRetry: () => ref.invalidate(aiMarketingDraftsProvider)), data: (items) => items.isEmpty ? const _Empty(message: 'No AI campaign drafts are queued.') : Column(children: [for (final item in items) _MarketingTile(item: item)]))),
      ]),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon});
  final String label;
  final int value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(width: 180, child: Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [CircleAvatar(child: Icon(icon)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label), Text('$value', style: Theme.of(context).textTheme.headlineSmall)]))]))));
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 8), child]);
}

class _ContentJobTile extends StatelessWidget {
  const _ContentJobTile({required this.item});
  final AiContentJob item;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(leading: const Icon(Icons.article_outlined), title: Text(item.title), subtitle: Text('${item.contentType.replaceAll('_', ' ')} • ${item.category}'), trailing: Chip(label: Text(item.status.replaceAll('_', ' ')))));
}

class _MarketingTile extends StatelessWidget {
  const _MarketingTile({required this.item});
  final AiMarketingDraft item;
  @override
  Widget build(BuildContext context) {
    final scheduled = item.scheduledAt == null ? 'Not scheduled' : DateFormat('d MMM, h:mm a').format(item.scheduledAt!);
    return Card(child: ListTile(leading: const Icon(Icons.campaign_outlined), title: Text(item.title), subtitle: Text('${item.campaignType.replaceAll('_', ' ')} • ${item.audience} • $scheduled'), trailing: Chip(label: Text(item.status.replaceAll('_', ' ')))));
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(leading: const Icon(Icons.inbox_outlined), title: Text(message)));
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(leading: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error), title: Text(message), trailing: IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh))));
}
