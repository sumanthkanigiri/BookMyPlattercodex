import 'dart:convert';

import 'package:bookmyplatter/src/core/supabase/supabase_providers.dart';
import 'package:bookmyplatter/src/features/address/domain/address.dart';
import 'package:bookmyplatter/src/features/cart/domain/cart_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final crmRepositoryProvider = Provider<CrmRepository>((ref) {
  return CrmRepository(ref.watch(supabaseClientProvider));
});

class LeadDraft {
  const LeadDraft({
    required this.source,
    this.customerName = '',
    this.mobile = '',
    this.email = '',
    this.whatsappNumber = '',
    this.eventType = 'custom',
    this.eventDate,
    this.guestCount,
    this.foodPreference,
    this.budget,
    this.eventLocation = '',
    this.notes = '',
    this.bookingStatus = 'not_booked',
    this.paymentStatus = 'pending',
    this.metadata = const {},
  });

  final String source;
  final String customerName;
  final String mobile;
  final String email;
  final String whatsappNumber;
  final String eventType;
  final DateTime? eventDate;
  final int? guestCount;
  final String? foodPreference;
  final double? budget;
  final String eventLocation;
  final String notes;
  final String bookingStatus;
  final String paymentStatus;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toRpcParams() => {
        'p_source': source,
        'p_customer_name': customerName.trim(),
        'p_mobile': _digits(mobile),
        'p_email': email.trim(),
        'p_whatsapp_number': _digits(whatsappNumber.isEmpty ? mobile : whatsappNumber),
        'p_event_type': eventType,
        'p_event_date': eventDate?.toUtc().toIso8601String(),
        'p_guest_count': guestCount,
        'p_food_preference': foodPreference,
        'p_budget': budget,
        'p_event_location': eventLocation.trim(),
        'p_notes': notes.trim(),
        'p_booking_status': bookingStatus,
        'p_payment_status': paymentStatus,
        'p_metadata': metadata,
      };

  static String _digits(String value) => value.replaceAll(RegExp('[^0-9]'), '');
}

class CrmRepository {
  const CrmRepository(this._client);

  final SupabaseClient _client;

  Future<String> recordLead(LeadDraft draft) async {
    final id = await _client.rpc<String>('record_lead_activity', params: draft.toRpcParams());
    return id;
  }

  Future<String> recordCheckoutStarted({
    required List<CartItem> items,
    Address? address,
    DateTime? eventAt,
    String eventType = 'custom',
    String notes = '',
    double? total,
  }) {
    final user = _client.auth.currentUser;
    return recordLead(
      LeadDraft(
        source: 'checkout_started',
        customerName: (user?.userMetadata?['full_name'] as String?) ?? '',
        mobile: user?.phone ?? '',
        email: user?.email ?? '',
        eventType: eventType,
        eventDate: eventAt,
        guestCount: items.fold<int>(0, (sum, item) => sum + item.guests),
        foodPreference: _foodPreference(items),
        budget: total,
        eventLocation: address == null
            ? ''
            : '${address.line1}, ${address.area}, ${address.city} ${address.pincode}',
        notes: notes,
        bookingStatus: 'checkout_started',
        metadata: {
          'cart': [for (final item in items) _cartItemJson(item)],
          'origin': 'customer_checkout',
        },
      ),
    );
  }

  Future<String> recordWhatsAppClick({
    String source = 'whatsapp_click',
    String notes = 'Customer opened WhatsApp from BookMyPlatter.',
  }) {
    final user = _client.auth.currentUser;
    return recordLead(
      LeadDraft(
        source: source,
        customerName: (user?.userMetadata?['full_name'] as String?) ?? '',
        mobile: user?.phone ?? '',
        email: user?.email ?? '',
        whatsappNumber: user?.phone ?? '',
        notes: notes,
        metadata: {'origin': 'whatsapp_cta'},
      ),
    );
  }

  Future<String> requestCallback({
    required String name,
    required String mobile,
    String email = '',
    String eventType = 'custom',
    DateTime? eventDate,
    int? guestCount,
    String? foodPreference,
    double? budget,
    String eventLocation = '',
    String notes = '',
    String source = 'callback_request',
  }) {
    return recordLead(
      LeadDraft(
        source: source,
        customerName: name,
        mobile: mobile,
        email: email,
        whatsappNumber: mobile,
        eventType: eventType,
        eventDate: eventDate,
        guestCount: guestCount,
        foodPreference: foodPreference,
        budget: budget,
        eventLocation: eventLocation,
        notes: notes,
        metadata: {'origin': source},
      ),
    );
  }

  Future<String> requestFoodTasting({
    required String name,
    required String mobile,
    String email = '',
    DateTime? eventDate,
    int? guestCount,
    String eventLocation = '',
    String notes = '',
  }) {
    return requestCallback(
      name: name,
      mobile: mobile,
      email: email,
      eventType: 'food_tasting',
      eventDate: eventDate,
      guestCount: guestCount,
      eventLocation: eventLocation,
      notes: notes,
      source: 'food_tasting',
    );
  }

  static String? _foodPreference(List<CartItem> items) {
    if (items.isEmpty) return null;
    final hasVeg = items.any((item) => item.package.isVeg);
    final hasNonVeg = items.any((item) => !item.package.isVeg);
    if (hasVeg && hasNonVeg) return 'mixed';
    return hasVeg ? 'veg' : 'non_veg';
  }

  static Map<String, dynamic> _cartItemJson(CartItem item) => {
        'package_id': item.package.id,
        'package_name': item.package.name,
        'guest_count': item.guests,
        'price_per_guest': item.package.pricePerGuest,
        'is_veg': item.package.isVeg,
      };
}

String crmDeepLinkMessage({String leadId = ''}) {
  final suffix = leadId.isEmpty ? '' : '\nLead reference: $leadId';
  return Uri.encodeComponent(
    'Hi BookMyPlatter, I would like help planning my event.\n'
    'Name:\nMobile:\nEvent Date:\nGuest Count:\nVeg/Non Veg:\nLocation:\nBudget:\nSpecial Requirements:$suffix',
  );
}

String crmCartFingerprint(List<CartItem> items) {
  return base64Url.encode(utf8.encode(jsonEncode([
    for (final item in items) '${item.package.id}:${item.guests}',
  ])));
}
