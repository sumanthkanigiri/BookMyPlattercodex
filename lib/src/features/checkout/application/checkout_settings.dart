import 'package:bookmyplatter/src/core/supabase/supabase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CheckoutSettings {
  const CheckoutSettings({
    required this.codEnabled,
    required this.taxPercent,
    required this.deliveryCharge,
    required this.minimumLeadHours,
  });

  factory CheckoutSettings.fromMap(Map<String, dynamic> map) => CheckoutSettings(
        codEnabled: map['cod_enabled'] as bool? ?? false,
        taxPercent: (map['tax_percent'] as num?)?.toDouble() ?? 0,
        deliveryCharge: (map['delivery_charge'] as num?)?.toDouble() ?? 0,
        minimumLeadHours: (map['minimum_lead_hours'] as num?)?.toInt() ?? 24,
      );

  final bool codEnabled;
  final double taxPercent;
  final double deliveryCharge;
  final int minimumLeadHours;
}

final checkoutSettingsProvider = FutureProvider<CheckoutSettings>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final row = await client
      .from('app_config')
      .select('value')
      .eq('key', 'checkout_settings')
      .single();
  return CheckoutSettings.fromMap(row['value'] as Map<String, dynamic>);
});
