import 'package:bookmyplatter_admin/src/core/admin_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class OwnerDashboardSnapshot {
  const OwnerDashboardSnapshot({required this.owner, required this.sales, required this.customer, required this.website, required this.app, required this.booking, required this.marketing, required this.finance, required this.staff, required this.ai});

  factory OwnerDashboardSnapshot.fromMap(Map<String, dynamic> map) => OwnerDashboardSnapshot(
        owner: Map<String, dynamic>.from((map['owner_dashboard'] as Map?) ?? const {}),
        sales: Map<String, dynamic>.from((map['sales_analytics'] as Map?) ?? const {}),
        customer: Map<String, dynamic>.from((map['customer_analytics'] as Map?) ?? const {}),
        website: Map<String, dynamic>.from((map['website_analytics'] as Map?) ?? const {}),
        app: Map<String, dynamic>.from((map['app_analytics'] as Map?) ?? const {}),
        booking: Map<String, dynamic>.from((map['booking_analytics'] as Map?) ?? const {}),
        marketing: Map<String, dynamic>.from((map['marketing_analytics'] as Map?) ?? const {}),
        finance: Map<String, dynamic>.from((map['finance_analytics'] as Map?) ?? const {}),
        staff: Map<String, dynamic>.from((map['staff_analytics'] as Map?) ?? const {}),
        ai: Map<String, dynamic>.from((map['ai_reports'] as Map?) ?? const {}),
      );

  final Map<String, dynamic> owner;
  final Map<String, dynamic> sales;
  final Map<String, dynamic> customer;
  final Map<String, dynamic> website;
  final Map<String, dynamic> app;
  final Map<String, dynamic> booking;
  final Map<String, dynamic> marketing;
  final Map<String, dynamic> finance;
  final Map<String, dynamic> staff;
  final Map<String, dynamic> ai;
}

String metricText(Map<String, dynamic> data, String key) => data[key]?.toString() ?? '0';
double metricDouble(Map<String, dynamic> data, String key) => (data[key] as num?)?.toDouble() ?? 0;

class DashboardMetrics {
  const DashboardMetrics({required this.todayOrders, required this.upcomingEvents, required this.customers, required this.revenue});
  final int todayOrders;
  final int upcomingEvents;
  final int customers;
  final double revenue;
}

class AdminOrder {
  const AdminOrder({required this.id, required this.customer, required this.packageName, required this.eventAt, required this.status, required this.total});
  factory AdminOrder.fromMap(Map<String, dynamic> map) => AdminOrder(
        id: map['id'] as String,
        customer: (map['profiles'] as Map<String, dynamic>)['full_name'] as String,
        packageName: (map['packages'] as Map<String, dynamic>)['name'] as String,
        eventAt: DateTime.parse(map['event_at'] as String).toLocal(),
        status: map['status'] as String,
        total: (map['grand_total'] as num).toDouble(),
      );
  final String id;
  final String customer;
  final String packageName;
  final DateTime eventAt;
  final String status;
  final double total;
}

final dashboardMetricsProvider = FutureProvider<DashboardMetrics>((ref) async {
  final client = ref.watch(supabaseProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
  final end = DateTime(now.year, now.month, now.day + 1).toUtc().toIso8601String();
  final today = await client.from('orders').select('id').gte('created_at', start).lt('created_at', end).count(CountOption.exact);
  final upcoming = await client.from('orders').select('id').gte('event_at', now.toUtc().toIso8601String()).inFilter('status', ['placed', 'confirmed', 'preparing', 'out_for_delivery']).count(CountOption.exact);
  final customers = await client.from('profiles').select('id').eq('role', 'customer').count(CountOption.exact);
  final payments = await client.from('payments').select('amount').eq('status', 'paid');
  return DashboardMetrics(
    todayOrders: today.count,
    upcomingEvents: upcoming.count,
    customers: customers.count,
    revenue: payments.fold<double>(0, (sum, row) => sum + (row['amount'] as num).toDouble()),
  );
});

final recentAdminOrdersProvider = FutureProvider<List<AdminOrder>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final rows = await client
      .from('orders')
      .select('id,event_at,status,grand_total,profiles!orders_customer_id_fkey(full_name),packages(name)')
      .order('created_at', ascending: false)
      .limit(12);
  return [for (final row in rows) AdminOrder.fromMap(row)];
});


final ownerDashboardSnapshotProvider = FutureProvider<OwnerDashboardSnapshot>((ref) async {
  final payload = await ref.watch(supabaseProvider).rpc<dynamic>('owner_dashboard_snapshot');
  return OwnerDashboardSnapshot.fromMap(Map<String, dynamic>.from(payload as Map));
});

final ownerDashboardRealtimeProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(supabaseProvider).from('orders').stream(primaryKey: ['id']);
});
