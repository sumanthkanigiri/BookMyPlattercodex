import 'dart:typed_data';
import 'dart:async';

import 'package:bookmyplatter/src/features/orders/application/order_controller.dart';
import 'package:bookmyplatter/src/features/orders/domain/order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderDetailsScreen extends ConsumerWidget {
  const OrderDetailsScreen({required this.orderId, this.confirmation = false, super.key});
  final String orderId;
  final bool confirmation;

  static const statuses = [
    ('placed', 'Order Placed', Icons.receipt_long),
    ('confirmed', 'Order Confirmed', Icons.verified_outlined),
    ('preparing', 'Food Preparation', Icons.soup_kitchen_outlined),
    ('packing', 'Packing', Icons.inventory_2_outlined),
    ('out_for_delivery', 'Team Dispatched', Icons.local_shipping_outlined),
    ('arrived_at_venue', 'Arrived at Venue', Icons.location_on_outlined),
    ('event_started', 'Event Started', Icons.celebration_outlined),
    ('delivered', 'Event Completed', Icons.task_alt),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId));
    return Scaffold(
      appBar: AppBar(title: Text(confirmation ? 'Booking confirmed' : 'Order details')),
      body: order.when(
        loading: () => const _OrderSkeleton(),
        error: (error, _) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(orderProvider(orderId)),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ),
        data: (item) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(orderProvider(orderId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (confirmation) _SuccessHeader(order: item),
              _SummaryCard(order: item),
              _EventCountdown(eventAt: item.eventAt),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.celebration_outlined),
                      title: Text(_label(item.eventType)),
                      subtitle: Text('${item.guestCount} guests • ${_label(item.paymentMethod)}'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(item.deliveryAddress),
                      trailing: const Icon(Icons.directions_outlined),
                      onTap: () => launchUrl(
                        Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(item.deliveryAddress)}'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                    if (item.notes?.isNotEmpty ?? false)
                      ListTile(
                        leading: const Icon(Icons.notes),
                        title: const Text('Special instructions'),
                        subtitle: Text(item.notes!),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('Live tracking', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              _TrackingTimeline(order: item),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Printing.layoutPdf(onLayout: (_) => _invoice(item)),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Invoice'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Share.share(_shareText(item)),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse('https://wa.me/?text=${Uri.encodeComponent(_shareText(item))}'),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Share on WhatsApp'),
              ),
              if ({'placed', 'confirmed'}.contains(item.status))
                TextButton.icon(
                  onPressed: () => _reschedule(context, ref, item),
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: const Text('Reschedule booking'),
                ),
              if (confirmation)
                TextButton(onPressed: () => context.go('/home'), child: const Text('Back to home')),
            ],
          ),
        ),
      ),
    );
  }

  String _shareText(PlatterOrder order) =>
      'BookMyPlatter booking ${order.id}\n${order.packageName}\n${order.guestCount} guests\n${DateFormat('d MMM yyyy, h:mm a').format(order.eventAt)}\nTotal: ₹${order.total.toStringAsFixed(0)}';

  String _label(String value) => value
      .split('_')
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  Future<void> _reschedule(BuildContext context, WidgetRef ref, PlatterOrder order) async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final initialDate = order.eventAt.isAfter(firstDate) ? order.eventAt : firstDate;
    final date = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 365)),
      initialDate: initialDate,
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(order.eventAt));
    if (time == null || !context.mounted) return;
    final eventAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    try {
      await ref.read(orderControllerProvider.notifier).reschedule(order.id, eventAt);
      ref.invalidate(orderProvider(order.id));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This booking can no longer be rescheduled')),
        );
      }
    }
  }

  Future<Uint8List> _invoice(PlatterOrder order) async {
    final document = pw.Document(title: 'BookMyPlatter Invoice ${order.id}');
    document.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (_) => pw.Padding(
        padding: const pw.EdgeInsets.all(28),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('BookMyPlatter', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
          pw.Text('Booking Invoice', style: const pw.TextStyle(fontSize: 18)),
          pw.SizedBox(height: 24),
          pw.Text('Order ID: ${order.id}'),
          pw.Text('Event: ${DateFormat('d MMM yyyy, h:mm a').format(order.eventAt)}'),
          pw.Text('Address: ${order.deliveryAddress}'),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(headers: ['Package', 'Guests', 'Subtotal'], data: [[order.packageName, '${order.guestCount}', 'INR ${order.subtotal.toStringAsFixed(2)}']]),
          pw.SizedBox(height: 16),
          pw.Align(alignment: pw.Alignment.centerRight, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Discount: INR ${order.discount.toStringAsFixed(2)}'),
            pw.Text('GST: INR ${order.tax.toStringAsFixed(2)}'),
            pw.Text('Grand Total: INR ${order.total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ])),
        ]),
      ),
    ));
    return document.save();
  }
}

class _SuccessHeader extends StatelessWidget {
  const _SuccessHeader({required this.order});
  final PlatterOrder order;
  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFFF0E9FC),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const CircleAvatar(radius: 34, backgroundColor: Color(0xFF3C1285), child: Icon(Icons.check, color: Colors.white, size: 38)),
            const SizedBox(height: 14),
            Text('Your booking is confirmed!', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('Order #${order.id.substring(0, 8).toUpperCase()}'),
          ]),
        ),
      );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.order});
  final PlatterOrder order;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(order.packageName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text('${order.guestCount} guests • ${DateFormat('d MMM, h:mm a').format(order.eventAt)}'),
            Text(order.deliveryAddress),
            const Divider(height: 24),
            Text('₹${order.total.toStringAsFixed(0)}', style: Theme.of(context).textTheme.headlineSmall),
          ]),
        ),
      );
}

class _EventCountdown extends StatefulWidget {
  const _EventCountdown({required this.eventAt});
  final DateTime eventAt;

  @override
  State<_EventCountdown> createState() => _EventCountdownState();
}

class _EventCountdownState extends State<_EventCountdown> {
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.eventAt.difference(DateTime.now());
    if (remaining.isNegative) return const SizedBox.shrink();
    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    final minutes = remaining.inMinutes.remainder(60);
    return Card(
      color: const Color(0xFFF8F3E2),
      child: ListTile(
        leading: const Icon(Icons.timer_outlined, color: Color(0xFF3C1285)),
        title: const Text('Event countdown'),
        subtitle: Text('$days days • $hours hours • $minutes minutes'),
      ),
    );
  }
}

class _TrackingTimeline extends StatelessWidget {
  const _TrackingTimeline({required this.order});
  final PlatterOrder order;
  @override
  Widget build(BuildContext context) {
    final current = OrderDetailsScreen.statuses.indexWhere((item) => item.$1 == order.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          for (var index = 0; index < OrderDetailsScreen.statuses.length; index++)
            _timelineTile(index, current),
        ]),
      ),
    );
  }

  Widget _timelineTile(int index, int current) {
    OrderStatusEvent? matchingEvent;
    for (final event in order.events) {
      if (event.status == OrderDetailsScreen.statuses[index].$1) matchingEvent = event;
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: index <= current ? const Color(0xFF3C1285) : const Color(0xFFE8E3F0),
        child: Icon(OrderDetailsScreen.statuses[index].$3, color: index <= current ? Colors.white : Colors.black45),
      ),
      title: Text(OrderDetailsScreen.statuses[index].$2),
      subtitle: matchingEvent == null ? null : Text(DateFormat('d MMM, h:mm a').format(matchingEvent.createdAt)),
    );
  }
}

class _OrderSkeleton extends StatelessWidget {
  const _OrderSkeleton();
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}
