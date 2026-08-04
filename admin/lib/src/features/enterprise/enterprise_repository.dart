import 'package:bookmyplatter_admin/src/core/admin_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EnterpriseDashboardMetrics {
  const EnterpriseDashboardMetrics({
    required this.todayOrders,
    required this.todayRevenue,
    required this.todayEnquiries,
    required this.todayVisitors,
    required this.activeUsers,
    required this.pendingPayments,
    required this.pendingFollowUps,
    required this.checkoutRecovery,
    required this.foodTasting,
    required this.todayDeliveries,
    required this.kitchenQueue,
    required this.upcomingEvents,
    required this.tomorrowEvents,
    required this.openTasks,
  });

  final int todayOrders;
  final double todayRevenue;
  final int todayEnquiries;
  final int todayVisitors;
  final int activeUsers;
  final int pendingPayments;
  final int pendingFollowUps;
  final int checkoutRecovery;
  final int foodTasting;
  final int todayDeliveries;
  final int kitchenQueue;
  final int upcomingEvents;
  final int tomorrowEvents;
  final int openTasks;
}

class EnterpriseCalendarEvent {
  const EnterpriseCalendarEvent({required this.id, required this.title, required this.eventAt, required this.status, required this.guests, required this.venue});

  factory EnterpriseCalendarEvent.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    final package = map['packages'] as Map<String, dynamic>?;
    return EnterpriseCalendarEvent(
      id: map['id'] as String,
      title: '${package?['name'] ?? 'Booking'} • ${profile?['full_name'] ?? 'Customer'}',
      eventAt: DateTime.parse(map['event_at'] as String).toLocal(),
      status: map['status'] as String? ?? 'placed',
      guests: map['guest_count'] as int? ?? 0,
      venue: map['delivery_address'] as String? ?? 'Venue pending',
    );
  }

  final String id;
  final String title;
  final DateTime eventAt;
  final String status;
  final int guests;
  final String venue;
}

class EnterpriseKitchenItem {
  const EnterpriseKitchenItem({required this.id, required this.station, required this.status, required this.readyBy, required this.orderId, required this.chefName});

  factory EnterpriseKitchenItem.fromMap(Map<String, dynamic> map) {
    final chef = map['profiles'] as Map<String, dynamic>?;
    return EnterpriseKitchenItem(
      id: map['id'] as String,
      station: map['station'] as String? ?? 'main_kitchen',
      status: map['status'] as String? ?? 'queued',
      readyBy: map['ready_by'] == null ? null : DateTime.parse(map['ready_by'] as String).toLocal(),
      orderId: map['order_id'] as String,
      chefName: chef?['full_name'] as String? ?? 'Unassigned',
    );
  }

  final String id;
  final String station;
  final String status;
  final DateTime? readyBy;
  final String orderId;
  final String chefName;
}

class EnterpriseStaffTask {
  const EnterpriseStaffTask({required this.id, required this.title, required this.module, required this.status, required this.priority, required this.dueAt, required this.assignee});

  factory EnterpriseStaffTask.fromMap(Map<String, dynamic> map) {
    final assignee = map['profiles'] as Map<String, dynamic>?;
    return EnterpriseStaffTask(
      id: map['id'] as String,
      title: map['title'] as String,
      module: map['module'] as String? ?? 'operations',
      status: map['status'] as String? ?? 'open',
      priority: map['priority'] as String? ?? 'medium',
      dueAt: map['due_at'] == null ? null : DateTime.parse(map['due_at'] as String).toLocal(),
      assignee: assignee?['full_name'] as String? ?? 'Unassigned',
    );
  }

  final String id;
  final String title;
  final String module;
  final String status;
  final String priority;
  final DateTime? dueAt;
  final String assignee;
}

class EnterpriseFinanceSummary {
  const EnterpriseFinanceSummary({required this.revenue, required this.expenses, required this.purchaseOrders, required this.pendingVendorPayments, required this.profit});
  final double revenue;
  final double expenses;
  final double purchaseOrders;
  final int pendingVendorPayments;
  final double profit;
}

class EnterpriseCmsSummary {
  const EnterpriseCmsSummary({required this.banners, required this.blogs, required this.faqs, required this.testimonials, required this.seoPages});
  final int banners;
  final int blogs;
  final int faqs;
  final int testimonials;
  final int seoPages;
}

class EnterpriseMarketingSummary {
  const EnterpriseMarketingSummary({required this.runningCampaigns, required this.scheduledCampaigns, required this.sent, required this.delivered, required this.failed});
  final int runningCampaigns;
  final int scheduledCampaigns;
  final int sent;
  final int delivered;
  final int failed;
}

DateTime get _todayStart {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime get _tomorrowStart => _todayStart.add(const Duration(days: 1));
DateTime get _dayAfterTomorrowStart => _todayStart.add(const Duration(days: 2));

final enterpriseDashboardProvider = FutureProvider<EnterpriseDashboardMetrics>((ref) async {
  final client = ref.watch(supabaseProvider);
  final start = _todayStart.toUtc().toIso8601String();
  final end = _tomorrowStart.toUtc().toIso8601String();
  final tomorrowEnd = _dayAfterTomorrowStart.toUtc().toIso8601String();
  final activeCutoff = DateTime.now().subtract(const Duration(minutes: 5)).toUtc().toIso8601String();

  final todayOrders = await client.from('orders').select('id,grand_total').gte('created_at', start).lt('created_at', end).limit(500);
  final todayEnquiries = await client.from('leads').select('id').gte('created_at', start).lt('created_at', end).count(CountOption.exact);
  final todayVisitors = await client.from('customer_activity').select('id').gte('created_at', start).lt('created_at', end).count(CountOption.exact);
  final activeUsers = await client.from('customer_activity').select('id').gte('created_at', activeCutoff).count(CountOption.exact);
  final pendingPayments = await client.from('payments').select('id').inFilter('status', ['pending', 'failed']).count(CountOption.exact);
  final followUps = await client.from('followups').select('id').lte('due_at', end).inFilter('status', ['queued', 'failed']).count(CountOption.exact);
  final recoveries = await client.from('checkout_recovery').select('id').inFilter('status', ['queued', 'failed']).count(CountOption.exact);
  final tastings = await client.from('leads').select('id').or('event_type.ilike.%tasting%,status.eq.need_tasting').count(CountOption.exact);
  final deliveries = await client.from('orders').select('id').gte('event_at', start).lt('event_at', end).inFilter('status', ['out_for_delivery', 'delivered']).count(CountOption.exact);
  final kitchen = await client.from('kitchen_queue').select('id').not('status', 'in', '(completed,dispatched)').count(CountOption.exact);
  final upcoming = await client.from('orders').select('id').gte('event_at', DateTime.now().toUtc().toIso8601String()).inFilter('status', ['placed', 'confirmed', 'preparing', 'out_for_delivery']).count(CountOption.exact);
  final tomorrow = await client.from('orders').select('id').gte('event_at', end).lt('event_at', tomorrowEnd).count(CountOption.exact);
  final tasks = await client.from('admin_tasks').select('id').inFilter('status', ['open', 'in_progress', 'blocked']).count(CountOption.exact);

  return EnterpriseDashboardMetrics(
    todayOrders: todayOrders.length,
    todayRevenue: todayOrders.fold<double>(0, (sum, row) => sum + ((row['grand_total'] as num?)?.toDouble() ?? 0)),
    todayEnquiries: todayEnquiries.count,
    todayVisitors: todayVisitors.count,
    activeUsers: activeUsers.count,
    pendingPayments: pendingPayments.count,
    pendingFollowUps: followUps.count,
    checkoutRecovery: recoveries.count,
    foodTasting: tastings.count,
    todayDeliveries: deliveries.count,
    kitchenQueue: kitchen.count,
    upcomingEvents: upcoming.count,
    tomorrowEvents: tomorrow.count,
    openTasks: tasks.count,
  );
});

final enterpriseCalendarProvider = FutureProvider<List<EnterpriseCalendarEvent>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final rows = await client
      .from('orders')
      .select('id,event_at,status,guest_count,delivery_address,profiles!orders_customer_id_fkey(full_name),packages(name)')
      .gte('event_at', _todayStart.toUtc().toIso8601String())
      .order('event_at')
      .limit(30);
  return [for (final row in rows) EnterpriseCalendarEvent.fromMap(row)];
});

final enterpriseKitchenProvider = FutureProvider<List<EnterpriseKitchenItem>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final rows = await client.from('kitchen_queue').select('id,order_id,station,status,ready_by,profiles!kitchen_queue_chef_id_fkey(full_name)').order('ready_by').limit(20);
  return [for (final row in rows) EnterpriseKitchenItem.fromMap(row)];
});

final enterpriseTasksProvider = FutureProvider<List<EnterpriseStaffTask>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final rows = await client.from('admin_tasks').select('id,title,module,status,priority,due_at,profiles!admin_tasks_assigned_to_fkey(full_name)').order('due_at').limit(20);
  return [for (final row in rows) EnterpriseStaffTask.fromMap(row)];
});

final enterpriseFinanceProvider = FutureProvider<EnterpriseFinanceSummary>((ref) async {
  final client = ref.watch(supabaseProvider);
  final start = DateTime(_todayStart.year, _todayStart.month, 1).toUtc().toIso8601String();
  final revenueRows = await client.from('payments').select('amount').eq('status', 'paid').gte('created_at', start).limit(1000);
  final expenseRows = await client.from('finance_expenses').select('amount,tax_amount,payment_status').gte('expense_date', start.substring(0, 10)).limit(1000);
  final purchaseRows = await client.from('purchase_orders').select('grand_total,status').gte('order_date', start.substring(0, 10)).limit(1000);
  final revenue = revenueRows.fold<double>(0, (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0));
  final expenses = expenseRows.fold<double>(0, (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0) + ((row['tax_amount'] as num?)?.toDouble() ?? 0));
  final purchaseOrders = purchaseRows.fold<double>(0, (sum, row) => sum + ((row['grand_total'] as num?)?.toDouble() ?? 0));
  final pendingVendorPayments = expenseRows.where((row) => row['payment_status'] != 'paid').length + purchaseRows.where((row) => row['status'] != 'paid').length;
  return EnterpriseFinanceSummary(revenue: revenue, expenses: expenses, purchaseOrders: purchaseOrders, pendingVendorPayments: pendingVendorPayments, profit: revenue - expenses - purchaseOrders);
});

final enterpriseCmsProvider = FutureProvider<EnterpriseCmsSummary>((ref) async {
  final client = ref.watch(supabaseProvider);
  final banners = await client.from('banners').select('id').count(CountOption.exact);
  final blogs = await client.from('website_blog_posts').select('id').count(CountOption.exact);
  final faqs = await client.from('website_faqs').select('id').count(CountOption.exact);
  final testimonials = await client.from('website_reviews').select('id').count(CountOption.exact);
  final seoPages = await client.from('website_seo_pages').select('id').count(CountOption.exact);
  return EnterpriseCmsSummary(banners: banners.count, blogs: blogs.count, faqs: faqs.count, testimonials: testimonials.count, seoPages: seoPages.count);
});

final enterpriseMarketingProvider = FutureProvider<EnterpriseMarketingSummary>((ref) async {
  final client = ref.watch(supabaseProvider);
  final campaigns = await client.from('marketing_campaigns').select('status,sent_count,delivered_count,failed_count').limit(500);
  return EnterpriseMarketingSummary(
    runningCampaigns: campaigns.where((row) => row['status'] == 'running').length,
    scheduledCampaigns: campaigns.where((row) => row['status'] == 'scheduled').length,
    sent: campaigns.fold<int>(0, (sum, row) => sum + ((row['sent_count'] as num?)?.toInt() ?? 0)),
    delivered: campaigns.fold<int>(0, (sum, row) => sum + ((row['delivered_count'] as num?)?.toInt() ?? 0)),
    failed: campaigns.fold<int>(0, (sum, row) => sum + ((row['failed_count'] as num?)?.toInt() ?? 0)),
  );
});

final enterpriseRealtimeProvider = StreamProvider<void>((ref) {
  final client = ref.watch(supabaseProvider);
  return client
      .from('orders')
      .stream(primaryKey: ['id'])
      .map((_) => null);
});
