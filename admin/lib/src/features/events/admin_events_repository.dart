import 'package:bookmyplatter_admin/src/core/admin_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventMetrics {
  const EventMetrics({required this.today, required this.tomorrow, required this.upcoming, required this.completed, required this.cancelled});
  final int today;
  final int tomorrow;
  final int upcoming;
  final int completed;
  final int cancelled;
}

class CompanyEventSummary {
  const CompanyEventSummary({required this.id, required this.eventNumber, required this.eventName, required this.eventType, required this.eventAt, required this.venueAddress, required this.guestCount, required this.status, required this.kitchenStatus, required this.staffStatus, required this.deliveryStatus});

  factory CompanyEventSummary.fromMap(Map<String, dynamic> map) => CompanyEventSummary(
        id: map['id'] as String,
        eventNumber: map['event_number'] as String? ?? '',
        eventName: map['event_name'] as String? ?? 'Event',
        eventType: map['event_type'] as String? ?? 'private_party',
        eventAt: DateTime.parse(map['event_at'] as String).toLocal(),
        venueAddress: map['venue_address'] as String? ?? '',
        guestCount: (map['guest_count'] as num?)?.toInt() ?? 0,
        status: map['status'] as String? ?? 'upcoming',
        kitchenStatus: map['kitchen_status'] as String? ?? 'not_started',
        staffStatus: map['staff_status'] as String? ?? 'unassigned',
        deliveryStatus: map['delivery_status'] as String? ?? 'unassigned',
      );

  final String id;
  final String eventNumber;
  final String eventName;
  final String eventType;
  final DateTime eventAt;
  final String venueAddress;
  final int guestCount;
  final String status;
  final String kitchenStatus;
  final String staffStatus;
  final String deliveryStatus;
}

DateTime get _todayStart {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

final eventMetricsProvider = FutureProvider<EventMetrics>((ref) async {
  final client = ref.watch(supabaseProvider);
  final todayStart = _todayStart.toUtc().toIso8601String();
  final tomorrowStart = _todayStart.add(const Duration(days: 1)).toUtc().toIso8601String();
  final dayAfterTomorrow = _todayStart.add(const Duration(days: 2)).toUtc().toIso8601String();
  final today = await client.from('company_events').select('id').gte('event_at', todayStart).lt('event_at', tomorrowStart).count(CountOption.exact);
  final tomorrow = await client.from('company_events').select('id').gte('event_at', tomorrowStart).lt('event_at', dayAfterTomorrow).count(CountOption.exact);
  final upcoming = await client.from('company_events').select('id').eq('status', 'upcoming').count(CountOption.exact);
  final completed = await client.from('company_events').select('id').eq('status', 'completed').count(CountOption.exact);
  final cancelled = await client.from('company_events').select('id').eq('status', 'cancelled').count(CountOption.exact);
  return EventMetrics(today: today.count, tomorrow: tomorrow.count, upcoming: upcoming.count, completed: completed.count, cancelled: cancelled.count);
});

final companyEventsProvider = FutureProvider<List<CompanyEventSummary>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final rows = await client
      .from('company_events')
      .select('id,event_number,event_name,event_type,event_at,venue_address,guest_count,status,kitchen_status,staff_status,delivery_status')
      .order('event_at')
      .limit(100);
  return [for (final row in rows) CompanyEventSummary.fromMap(row)];
});

final companyEventsRealtimeProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final client = ref.watch(supabaseProvider);
  return client.from('company_events').stream(primaryKey: ['id']);
});
