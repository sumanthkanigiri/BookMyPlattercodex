import 'dart:async';

import 'package:bookmyplatter_admin/src/core/admin_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KitchenOrder {
  const KitchenOrder({required this.id, required this.customerId, required this.packageName, required this.customer, required this.eventAt, required this.status, required this.guests, required this.address, this.notes, this.kitchenNotes});
  factory KitchenOrder.fromMap(Map<String, dynamic> map) => KitchenOrder(
        id: map['id'] as String,
        customerId: map['customer_id'] as String,
        packageName: ((map['packages'] as Map<String, dynamic>?)?['name'] ?? 'Package') as String,
        customer: ((map['profiles'] as Map<String, dynamic>?)?['full_name'] ?? 'Customer') as String,
        eventAt: DateTime.parse(map['event_at'] as String).toLocal(),
        status: map['status'] as String,
        guests: map['guest_count'] as int,
        address: map['delivery_address'] as String,
        notes: map['notes'] as String?,
        kitchenNotes: (map['order_operations'] as Map<String, dynamic>?)?['kitchen_notes'] as String?,
      );
  final String id;
  final String customerId;
  final String packageName;
  final String customer;
  final DateTime eventAt;
  final String status;
  final int guests;
  final String address;
  final String? notes;
  final String? kitchenNotes;
}

class InventoryItem {
  const InventoryItem({required this.id, required this.name, required this.unit, required this.quantity, required this.reorderLevel, required this.unitCost});
  factory InventoryItem.fromMap(Map<String, dynamic> map) => InventoryItem(id: map['id'] as String, name: map['name'] as String, unit: map['unit'] as String, quantity: (map['quantity'] as num).toDouble(), reorderLevel: (map['reorder_level'] as num).toDouble(), unitCost: (map['unit_cost'] as num).toDouble());
  final String id;
  final String name;
  final String unit;
  final double quantity;
  final double reorderLevel;
  final double unitCost;
  bool get lowStock => quantity <= reorderLevel;
}

class StaffMember {
  const StaffMember({required this.id, required this.name, required this.employeeCode, required this.department, required this.jobTitle, required this.phone, required this.active});
  factory StaffMember.fromMap(Map<String, dynamic> map) => StaffMember(
        id: map['id'] as String,
        name: ((map['profiles'] as Map<String, dynamic>?)?['full_name'] ?? 'Staff member') as String,
        employeeCode: map['employee_code'] as String,
        department: map['department'] as String,
        jobTitle: map['job_title'] as String,
        phone: map['phone'] as String,
        active: map['is_active'] as bool,
      );
  final String id;
  final String name;
  final String employeeCode;
  final String department;
  final String jobTitle;
  final String phone;
  final bool active;
}

class DeliveryAssignment {
  const DeliveryAssignment({required this.id, required this.orderId, required this.status, required this.staffName, required this.address, this.latitude, this.longitude, this.eta});
  factory DeliveryAssignment.fromMap(Map<String, dynamic> map) {
    final staff = map['staff_members'] as Map<String, dynamic>?;
    return DeliveryAssignment(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      status: map['status'] as String,
      staffName: ((staff?['profiles'] as Map<String, dynamic>?)?['full_name'] ?? 'Delivery team') as String,
      address: ((map['orders'] as Map<String, dynamic>?)?['delivery_address'] ?? '') as String,
      latitude: (map['current_latitude'] as num?)?.toDouble(),
      longitude: (map['current_longitude'] as num?)?.toDouble(),
      eta: map['estimated_arrival_at'] == null ? null : DateTime.parse(map['estimated_arrival_at'] as String).toLocal(),
    );
  }
  final String id;
  final String orderId;
  final String status;
  final String staffName;
  final String address;
  final double? latitude;
  final double? longitude;
  final DateTime? eta;
}

class FinanceSummary {
  const FinanceSummary({required this.paid, required this.pending, required this.refunded, required this.expenses, required this.gst});
  final double paid;
  final double pending;
  final double refunded;
  final double expenses;
  final double gst;
  double get profit => paid - refunded - expenses;
}

class OperationsRepository {
  const OperationsRepository(this.client);
  final SupabaseClient client;

  Future<List<KitchenOrder>> kitchenOrders() async {
    final start = DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String();
    final rows = await client.from('orders').select('id,customer_id,event_at,status,guest_count,delivery_address,notes,packages(name),profiles!orders_customer_id_fkey(full_name),order_operations(kitchen_notes)').gte('event_at', start).order('event_at').limit(250);
    return [for (final row in rows) KitchenOrder.fromMap(row)];
  }

  Future<void> saveKitchenNotes(String orderId, String notes) => client.from('order_operations').upsert({'order_id': orderId, 'kitchen_notes': notes.trim(), 'updated_by': client.auth.currentUser!.id, 'updated_at': DateTime.now().toUtc().toIso8601String()});

  Future<List<InventoryItem>> inventory() async {
    final rows = await client.from('inventory_items').select().order('name');
    return [for (final row in rows) InventoryItem.fromMap(row)];
  }

  Future<void> saveInventoryItem({String? id, required String name, required String unit, required double reorderLevel, required double unitCost}) async {
    final values = {'name': name.trim(), 'unit': unit, 'reorder_level': reorderLevel, 'unit_cost': unitCost};
    if (id == null) await client.from('inventory_items').insert(values); else await client.from('inventory_items').update(values).eq('id', id);
  }

  Future<void> moveStock({required String itemId, required String type, required double quantity, double? unitCost, String? reference}) => client.rpc('record_stock_movement', params: {'p_item_id': itemId, 'p_type': type, 'p_quantity': quantity, 'p_unit_cost': unitCost, 'p_reference': reference});

  Future<List<StaffMember>> staff() async {
    final rows = await client.from('staff_members').select('id,employee_code,department,job_title,phone,is_active,profiles(full_name)').order('employee_code');
    return [for (final row in rows) StaffMember.fromMap(row)];
  }

  Future<void> saveStaff({required String profileId, required String employeeCode, required String department, required String jobTitle, required String phone}) => client.from('staff_members').upsert({'id': profileId, 'employee_code': employeeCode.trim().toUpperCase(), 'department': department, 'job_title': jobTitle.trim(), 'phone': phone.trim()});

  Future<List<DeliveryAssignment>> deliveries() async {
    final rows = await client.from('delivery_assignments').select('id,order_id,status,current_latitude,current_longitude,estimated_arrival_at,orders(delivery_address),staff_members!delivery_assignments_delivery_person_id_fkey(profiles(full_name))').order('created_at', ascending: false).limit(200);
    return [for (final row in rows) DeliveryAssignment.fromMap(row)];
  }

  Future<String> assignDelivery({required String orderId, required String staffId, required DateTime eta}) async {
    final otp = await client.rpc<String>('assign_delivery', params: {'p_order_id': orderId, 'p_staff_id': staffId, 'p_eta': eta.toUtc().toIso8601String()});
    return otp;
  }

  Future<bool> verifyOtp(String orderId, String otp) => client.rpc<bool>('verify_delivery_otp', params: {'p_order_id': orderId, 'p_otp': otp});

  Future<FinanceSummary> finance() async {
    final payments = await client.from('payments').select('amount,status');
    final expenses = await client.from('business_expenses').select('amount,gst_amount');
    double paid = 0, pending = 0, refunded = 0, expenseTotal = 0, gst = 0;
    for (final row in payments) {
      final amount = (row['amount'] as num).toDouble();
      switch (row['status']) {
        case 'paid':
          paid += amount;
          break;
        case 'refunded':
          refunded += amount;
          break;
        default:
          pending += amount;
      }
    }
    for (final row in expenses) { expenseTotal += (row['amount'] as num).toDouble(); gst += (row['gst_amount'] as num).toDouble(); }
    return FinanceSummary(paid: paid, pending: pending, refunded: refunded, expenses: expenseTotal, gst: gst);
  }

  Future<void> addExpense({required String category, required String description, required double amount, required double gst}) => client.from('business_expenses').insert({'category': category.trim(), 'description': description.trim(), 'amount': amount, 'gst_amount': gst});

  Future<Map<String, dynamic>> notifyCustomer({required String userId, required String orderId, required String title, required String message, required List<String> channels}) async {
    final response = await client.functions.invoke('operations-notify', body: {'userId': userId, 'orderId': orderId, 'title': title.trim(), 'message': message.trim(), 'channels': channels});
    if (response.status < 200 || response.status >= 300) throw StateError((response.data as Map<String, dynamic>?)?['error']?.toString() ?? 'Notification delivery failed');
    return Map<String, dynamic>.from(response.data as Map);
  }
}

final operationsRepositoryProvider = Provider((ref) => OperationsRepository(ref.watch(supabaseProvider)));
final kitchenOrdersProvider = FutureProvider((ref) => ref.watch(operationsRepositoryProvider).kitchenOrders());
final inventoryProvider = FutureProvider((ref) => ref.watch(operationsRepositoryProvider).inventory());
final staffProvider = FutureProvider((ref) => ref.watch(operationsRepositoryProvider).staff());
final deliveriesProvider = FutureProvider((ref) => ref.watch(operationsRepositoryProvider).deliveries());
final financeProvider = FutureProvider((ref) => ref.watch(operationsRepositoryProvider).finance());

final operationsRealtimeProvider = Provider<void>((ref) {
  final client = ref.watch(supabaseProvider);
  void refreshKitchen(PostgresChangePayload _) => ref.invalidate(kitchenOrdersProvider);
  void refreshDelivery(PostgresChangePayload _) => ref.invalidate(deliveriesProvider);
  void refreshInventory(PostgresChangePayload _) => ref.invalidate(inventoryProvider);
  final channel = client
      .channel('operations-console')
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'orders', callback: refreshKitchen)
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'order_operations', callback: refreshKitchen)
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'delivery_assignments', callback: refreshDelivery)
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'inventory_items', callback: refreshInventory)
      .subscribe();
  ref.onDispose(() => client.removeChannel(channel));
});
