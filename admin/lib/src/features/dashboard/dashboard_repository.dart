import 'package:bookmyplatter_admin/src/core/admin_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
