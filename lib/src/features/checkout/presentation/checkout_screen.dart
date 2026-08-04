import 'package:bookmyplatter/src/core/errors/app_exception.dart';
import 'package:bookmyplatter/src/features/address/application/address_controller.dart';
import 'package:bookmyplatter/src/features/address/domain/address.dart';
import 'package:bookmyplatter/src/features/cart/application/cart_controller.dart';
import 'package:bookmyplatter/src/features/coupons/application/coupon_controller.dart';
import 'package:bookmyplatter/src/features/crm/application/crm_repository.dart';
import 'package:bookmyplatter/src/features/checkout/application/checkout_settings.dart';
import 'package:bookmyplatter/src/features/orders/application/order_controller.dart';
import 'package:bookmyplatter/src/features/payments/application/payment_service.dart';
import 'package:bookmyplatter/src/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final couponController = TextEditingController();
  final notesController = TextEditingController();
  String? selectedAddressId;
  DateTime? eventAt;
  String eventType = 'custom';
  String paymentMethod = 'razorpay';
  bool acceptedTerms = false;
  bool isSubmitting = false;
  String? trackedCheckoutFingerprint;

  Future<void> selectEventTime() async {
    final now = DateTime.now();
    final leadHours = ref.read(checkoutSettingsProvider).valueOrNull?.minimumLeadHours ?? 24;
    final earliest = now.add(Duration(hours: leadHours));
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(earliest.year, earliest.month, earliest.day),
      lastDate: now.add(const Duration(days: 365)),
      initialDate: eventAt ?? earliest,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: eventAt == null
          ? const TimeOfDay(hour: 12, minute: 0)
          : TimeOfDay.fromDateTime(eventAt!),
    );
    if (time == null) return;
    final selected = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (selected.isBefore(earliest)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bookings require at least $leadHours hours notice')),
        );
      }
      return;
    }
    setState(() => eventAt = selected);
  }

  @override
  void dispose() {
    couponController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartControllerProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final couponState = ref.watch(couponControllerProvider);
    final coupon = couponState.valueOrNull;
    final addressesState = ref.watch(addressControllerProvider);
    final checkoutSettingsState = ref.watch(checkoutSettingsProvider);
    final checkoutSettings = checkoutSettingsState.valueOrNull;
    final razorpayState = ref.watch(razorpayAvailabilityProvider);
    final razorpayAvailable = razorpayState.valueOrNull ?? false;
    final addresses = addressesState.valueOrNull ?? const [];
    Address? selectedAddress;
    for (final address in addresses) {
      if (address.id == selectedAddressId) selectedAddress = address;
    }
    selectedAddress ??= addresses.isEmpty ? null : addresses.first;
    final discount = coupon?.discountFor(subtotal) ?? 0;
    final tax = (subtotal - discount) * (checkoutSettings?.taxPercent ?? 0) / 100;
    final delivery = checkoutSettings?.deliveryCharge ?? 0;
    final total = subtotal - discount + tax + delivery;
    final checkoutFingerprint = crmCartFingerprint(items);
    if (items.isNotEmpty && trackedCheckoutFingerprint != checkoutFingerprint) {
      trackedCheckoutFingerprint = checkoutFingerprint;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(crmRepositoryProvider)
            .recordCheckoutStarted(
              items: items,
              address: selectedAddress,
              eventAt: eventAt,
              eventType: eventType,
              notes: notesController.text,
              total: total,
            )
            .catchError((_) => '');
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.event),
            title: const Text('Event date and time'),
            subtitle: Text(eventAt == null ? 'Select event schedule' : DateFormat('EEEE, d MMM yyyy • h:mm a').format(eventAt!)),
            trailing: const Icon(Icons.chevron_right),
            onTap: selectEventTime,
          ),
          DropdownButtonFormField<String>(
            value: eventType,
            decoration: const InputDecoration(
              labelText: 'Event type',
              prefixIcon: Icon(Icons.celebration_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'wedding', child: Text('Wedding')),
              DropdownMenuItem(value: 'birthday', child: Text('Birthday')),
              DropdownMenuItem(value: 'corporate', child: Text('Corporate')),
              DropdownMenuItem(value: 'house_warming', child: Text('House warming')),
              DropdownMenuItem(value: 'naming_ceremony', child: Text('Naming ceremony')),
              DropdownMenuItem(value: 'engagement', child: Text('Engagement')),
              DropdownMenuItem(value: 'anniversary', child: Text('Anniversary')),
              DropdownMenuItem(value: 'baby_shower', child: Text('Baby shower')),
              DropdownMenuItem(value: 'custom', child: Text('Custom event')),
            ],
            onChanged: (value) => setState(() => eventType = value ?? 'custom'),
          ),
          const SizedBox(height: 12),
          Text('Delivery address', style: Theme.of(context).textTheme.titleMedium),
          addressesState.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('Unable to load saved addresses'),
              subtitle: Text(error.toString()),
              trailing: IconButton(
                onPressed: () => ref.read(addressControllerProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
              ),
            ),
            data: (savedAddresses) => savedAddresses.isEmpty
                ? ListTile(
                    leading: const Icon(Icons.add_location_alt_outlined),
                    title: const Text('Add a saved address before checkout'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/addresses'),
                  )
                : Column(
                    children: [
                      for (final address in savedAddresses)
                        RadioListTile<String>(
                          value: address.id,
                          groupValue: selectedAddress?.id,
                          onChanged: (value) => setState(() => selectedAddressId = value),
                          title: Text(address.label),
                          subtitle: Text('${address.line1}, ${address.area}, ${address.city} ${address.pincode}'),
                        ),
                    ],
                  ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: couponController,
                  decoration: const InputDecoration(labelText: 'Coupon code'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: couponState.isLoading
                    ? null
                    : () async {
                        await ref
                            .read(couponControllerProvider.notifier)
                            .apply(couponController.text, subtotal);
                        if (!context.mounted) return;
                        final result = ref.read(couponControllerProvider);
                        if (result.hasError) {
                          final error = result.error;
                          final message = error is AppException ? error.message : 'Unable to validate coupon';
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                        }
                      },
                child: couponState.isLoading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Apply'),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: couponState.isLoading || subtotal <= 0
                  ? null
                  : () async {
                      await ref.read(couponControllerProvider.notifier).applyBest(subtotal);
                      if (!context.mounted) return;
                      final result = ref.read(couponControllerProvider);
                      final message = result.hasError
                          ? 'Unable to find the best offer'
                          : result.valueOrNull == null
                              ? 'No eligible offer is available for this cart'
                              : 'Best offer applied automatically';
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                    },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Apply best available offer'),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: notesController,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Special instructions',
              hintText: 'Allergies, serving preferences, venue directions…',
              border: OutlineInputBorder(),
            ),
          ),
          Text('Payment method', style: Theme.of(context).textTheme.titleMedium),
          checkoutSettingsState.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('Unable to load payment options'),
              trailing: IconButton(
                onPressed: () => ref.invalidate(checkoutSettingsProvider),
                icon: const Icon(Icons.refresh),
              ),
            ),
            data: (settings) => settings.codEnabled
                ? RadioListTile<String>(
                    value: 'cod',
                    groupValue: paymentMethod,
                    onChanged: (value) => setState(() => paymentMethod = value ?? 'razorpay'),
                    title: const Text('Cash on delivery'),
                    subtitle: const Text('Pay according to the confirmed order terms'),
                  )
                : const SizedBox.shrink(),
          ),
          RadioListTile<String>(
            value: 'razorpay',
            groupValue: paymentMethod,
            onChanged: razorpayAvailable ? (value) => setState(() => paymentMethod = value ?? 'razorpay') : null,
            title: const Text('Pay online with Razorpay'),
            subtitle: Text(razorpayState.isLoading ? 'Checking payment configuration…' : razorpayAvailable ? 'UPI, cards, netbanking, and supported wallets' : 'Razorpay is not configured in this environment'),
          ),
          if (razorpayState.hasError)
            ListTile(
              leading: const Icon(Icons.cloud_off_outlined),
              title: const Text('Unable to verify Razorpay configuration'),
              trailing: IconButton(onPressed: () => ref.invalidate(razorpayAvailabilityProvider), icon: const Icon(Icons.refresh)),
            ),
          const SizedBox(height: 16),
          _AmountRow(label: 'Subtotal', amount: subtotal),
          _AmountRow(label: 'Discount', amount: -discount),
          _AmountRow(label: 'Tax', amount: tax),
          _AmountRow(label: 'Delivery', amount: delivery),
          const Divider(),
          _AmountRow(label: 'Total', amount: total),
          CheckboxListTile(
            value: acceptedTerms,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) => setState(() => acceptedTerms = value ?? false),
            title: const Text('I agree to the booking terms and cancellation policy'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: items.isEmpty || selectedAddress == null || eventAt == null || !acceptedTerms || isSubmitting || checkoutSettings == null || (paymentMethod == 'razorpay' && !razorpayAvailable)
                ? null
                : () async {
                    setState(() => isSubmitting = true);
                    try {
                      final orderIds = await ref.read(orderControllerProvider.notifier).placeOrder(
                            items: items,
                            address: selectedAddress,
                            eventAt: eventAt!,
                            eventType: eventType,
                            paymentMethod: paymentMethod,
                            notes: notesController.text.trim(),
                            coupon: coupon,
                          );
                      if (paymentMethod == 'razorpay') {
                        final user = ref.read(authRepositoryProvider).currentUser;
                        await ref.read(paymentServiceProvider).pay(
                              orderId: orderIds.first,
                              name: user?.userMetadata?['full_name'] as String?,
                              phone: user?.phone,
                              email: user?.email,
                            );
                      }
                      ref.read(cartControllerProvider.notifier).clear();
                      if (context.mounted) context.go('/confirmation/${orderIds.first}');
                    } catch (error) {
                      if (!context.mounted) return;
                      final message = error is AppException ? error.message : 'Unable to place order';
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                    } finally {
                      if (mounted) setState(() => isSubmitting = false);
                    }
                  },
            child: isSubmitting
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Confirm order'),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.amount});
  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text('₹${amount.toStringAsFixed(0)}')],
      ),
    );
  }
}
