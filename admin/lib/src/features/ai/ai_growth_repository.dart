import 'package:bookmyplatter_admin/src/core/admin_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiGrowthSummary {
  const AiGrowthSummary({required this.blogJobs, required this.marketingDrafts, required this.assistantThreads, required this.reviewModeration});
  final int blogJobs;
  final int marketingDrafts;
  final int assistantThreads;
  final int reviewModeration;
}

class AiContentJob {
  const AiContentJob({required this.id, required this.contentType, required this.status, required this.title, required this.category, required this.scheduledPublishAt});
  factory AiContentJob.fromMap(Map<String, dynamic> map) => AiContentJob(
        id: map['id'] as String,
        contentType: map['content_type'] as String? ?? 'seo_blog',
        status: map['status'] as String? ?? 'scheduled',
        title: map['title'] as String? ?? '',
        category: map['category'] as String? ?? 'Catering Guides',
        scheduledPublishAt: map['scheduled_publish_at'] == null ? null : DateTime.parse(map['scheduled_publish_at'] as String).toLocal(),
      );
  final String id;
  final String contentType;
  final String status;
  final String title;
  final String category;
  final DateTime? scheduledPublishAt;
}

class AiMarketingDraft {
  const AiMarketingDraft({required this.id, required this.campaignType, required this.status, required this.title, required this.audience, required this.scheduledAt});
  factory AiMarketingDraft.fromMap(Map<String, dynamic> map) => AiMarketingDraft(
        id: map['id'] as String,
        campaignType: map['campaign_type'] as String? ?? 'push',
        status: map['status'] as String? ?? 'scheduled',
        title: map['title'] as String? ?? '',
        audience: map['audience'] as String? ?? 'customers',
        scheduledAt: map['scheduled_at'] == null ? null : DateTime.parse(map['scheduled_at'] as String).toLocal(),
      );
  final String id;
  final String campaignType;
  final String status;
  final String title;
  final String audience;
  final DateTime? scheduledAt;
}

final aiGrowthSummaryProvider = FutureProvider<AiGrowthSummary>((ref) async {
  final client = ref.watch(supabaseProvider);
  final blogJobs = await client.from('ai_content_jobs').select('id').neq('status', 'success').count(CountOption.exact);
  final marketingDrafts = await client.from('ai_marketing_campaign_drafts').select('id').neq('status', 'success').count(CountOption.exact);
  final assistantThreads = await client.from('ai_assistant_threads').select('id').eq('status', 'active').count(CountOption.exact);
  final reviewModeration = await client.from('review_moderation_queue').select('id').eq('status', 'pending').count(CountOption.exact);
  return AiGrowthSummary(blogJobs: blogJobs.count, marketingDrafts: marketingDrafts.count, assistantThreads: assistantThreads.count, reviewModeration: reviewModeration.count);
});

final aiContentJobsProvider = FutureProvider<List<AiContentJob>>((ref) async {
  final rows = await ref.watch(supabaseProvider).from('ai_content_jobs').select('id,content_type,status,title,category,scheduled_publish_at').order('created_at', ascending: false).limit(50);
  return [for (final row in rows) AiContentJob.fromMap(row)];
});

final aiMarketingDraftsProvider = FutureProvider<List<AiMarketingDraft>>((ref) async {
  final rows = await ref.watch(supabaseProvider).from('ai_marketing_campaign_drafts').select('id,campaign_type,status,title,audience,scheduled_at').order('created_at', ascending: false).limit(50);
  return [for (final row in rows) AiMarketingDraft.fromMap(row)];
});

final aiGrowthRealtimeProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(supabaseProvider).from('ai_content_jobs').stream(primaryKey: ['id']);
});
