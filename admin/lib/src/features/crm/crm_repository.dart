import 'package:bookmyplatter_admin/src/core/admin_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class NotificationTemplateConfig {
  const NotificationTemplateConfig({
    required this.templateKey,
    required this.feature,
    required this.channel,
    required this.smsMessageId,
    required this.whatsappTemplateName,
    required this.whatsappTemplateId,
    required this.enabled,
  });

  factory NotificationTemplateConfig.fromMap(Map<String, dynamic> map) =>
      NotificationTemplateConfig(
        templateKey: map['template_key'] as String,
        feature: map['feature'] as String,
        channel: map['channel'] as String,
        smsMessageId: map['sms_message_id'] as String? ?? '',
        whatsappTemplateName: map['whatsapp_template_name'] as String? ?? '',
        whatsappTemplateId: map['whatsapp_template_id'] as String? ?? '',
        enabled: map['enabled'] as bool? ?? true,
      );

  final String templateKey;
  final String feature;
  final String channel;
  final String smsMessageId;
  final String whatsappTemplateName;
  final String whatsappTemplateId;
  final bool enabled;
}

class CrmMetrics {
  const CrmMetrics({
    required this.todayLeads,
    required this.pendingLeads,
    required this.convertedLeads,
    required this.lostLeads,
    required this.abandonedCheckouts,
    required this.pendingFollowUps,
  });

  final int todayLeads;
  final int pendingLeads;
  final int convertedLeads;
  final int lostLeads;
  final int abandonedCheckouts;
  final int pendingFollowUps;
}

class CrmLead {
  const CrmLead({
    required this.id,
    required this.customerName,
    required this.mobile,
    required this.eventType,
    required this.guestCount,
    required this.source,
    required this.status,
    required this.bookingStatus,
    required this.paymentStatus,
    required this.nextFollowUpAt,
    required this.createdAt,
    required this.notes,
  });

  factory CrmLead.fromMap(Map<String, dynamic> map) => CrmLead(
        id: map['id'] as String,
        customerName: map['customer_name'] as String? ?? '',
        mobile: map['mobile'] as String? ?? '',
        eventType: map['event_type'] as String? ?? 'custom',
        guestCount: (map['guest_count'] as num?)?.toInt(),
        source: map['source'] as String? ?? 'enquiry',
        status: map['status'] as String? ?? 'new',
        bookingStatus: map['booking_status'] as String? ?? 'not_booked',
        paymentStatus: map['payment_status'] as String? ?? 'pending',
        nextFollowUpAt: map['next_follow_up_at'] == null
            ? null
            : DateTime.parse(map['next_follow_up_at'] as String).toLocal(),
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        notes: map['notes'] as String? ?? '',
      );

  final String id;
  final String customerName;
  final String mobile;
  final String eventType;
  final int? guestCount;
  final String source;
  final String status;
  final String bookingStatus;
  final String paymentStatus;
  final DateTime? nextFollowUpAt;
  final DateTime createdAt;
  final String notes;
}

final crmMetricsProvider = FutureProvider<CrmMetrics>((ref) async {
  final client = ref.watch(supabaseProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
  final end = DateTime(now.year, now.month, now.day + 1).toUtc().toIso8601String();
  final today = await client
      .from('leads')
      .select('id')
      .gte('created_at', start)
      .lt('created_at', end)
      .count(CountOption.exact);
  final pending = await client
      .from('leads')
      .select('id')
      .inFilter('status', ['new', 'contacted', 'qualified', 'follow_up'])
      .count(CountOption.exact);
  final converted = await client
      .from('leads')
      .select('id')
      .eq('status', 'converted')
      .count(CountOption.exact);
  final lost = await client
      .from('leads')
      .select('id')
      .eq('status', 'lost')
      .count(CountOption.exact);
  final abandoned = await client
      .from('checkout_recovery')
      .select('id')
      .isFilter('recovered_at', null)
      .isFilter('stopped_at', null)
      .count(CountOption.exact);
  final followUps = await client
      .from('followups')
      .select('id')
      .eq('status', 'queued')
      .lte('due_at', now.toUtc().toIso8601String())
      .count(CountOption.exact);
  return CrmMetrics(
    todayLeads: today.count,
    pendingLeads: pending.count,
    convertedLeads: converted.count,
    lostLeads: lost.count,
    abandonedCheckouts: abandoned.count,
    pendingFollowUps: followUps.count,
  );
});

final crmLeadsProvider = FutureProvider<List<CrmLead>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final rows = await client
      .from('leads')
      .select('id,customer_name,mobile,event_type,guest_count,source,status,booking_status,payment_status,next_follow_up_at,created_at,notes')
      .order('updated_at', ascending: false)
      .limit(100);
  return [for (final row in rows) CrmLead.fromMap(row)];
});

final crmLeadEventsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final client = ref.watch(supabaseProvider);
  return client.from('leads').stream(primaryKey: ['id']);
});


final notificationTemplateRepositoryProvider = Provider<NotificationTemplateRepository>((ref) {
  return NotificationTemplateRepository(ref.watch(supabaseProvider));
});

class NotificationTemplateRepository {
  const NotificationTemplateRepository(this._client);
  final SupabaseClient _client;

  Future<void> setEnabled({
    required String templateKey,
    required String channel,
    required bool enabled,
  }) async {
    await _client
        .from('notification_templates')
        .update({'enabled': enabled})
        .eq('template_key', templateKey)
        .eq('channel', channel);
  }
}

final notificationTemplatesProvider =
    FutureProvider<List<NotificationTemplateConfig>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final rows = await client
      .from('notification_templates')
      .select('template_key,feature,channel,sms_message_id,whatsapp_template_name,whatsapp_template_id,enabled')
      .order('feature')
      .order('channel');
  return [for (final row in rows) NotificationTemplateConfig.fromMap(row)];
});
