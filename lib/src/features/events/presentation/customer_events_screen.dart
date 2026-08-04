import 'package:bookmyplatter/src/features/events/application/customer_event_controller.dart';
import 'package:bookmyplatter/src/features/events/domain/customer_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class CustomerEventsScreen extends ConsumerWidget {
  const CustomerEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(customerEventsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My events')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEventSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add event'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(customerEventsProvider.notifier).refresh(),
        child: events.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.event_busy, size: 48),
              const SizedBox(height: 12),
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => ref.read(customerEventsProvider.notifier).refresh(), child: const Text('Retry')),
            ],
          ),
          data: (items) => items.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: const [
                    Icon(Icons.celebration_outlined, size: 56),
                    SizedBox(height: 12),
                    Text('Save wedding, birthday, corporate and housewarming events to speed up checkout.', textAlign: TextAlign.center),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.event_available)),
                        title: Text(item.name),
                        subtitle: Text('${item.type.replaceAll('_', ' ')} • ${item.guestCount} guests\n${DateFormat('EEE, d MMM yyyy • h:mm a').format(item.eventAt)}'),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') _showEventSheet(context, ref, event: item);
                            if (value == 'delete') ref.read(customerEventsProvider.notifier).remove(item.id);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  static Future<void> _showEventSheet(BuildContext context, WidgetRef ref, {CustomerEvent? event}) async {
    final name = TextEditingController(text: event?.name ?? '');
    final venue = TextEditingController(text: event?.venueName ?? '');
    final guests = TextEditingController(text: '${event?.guestCount ?? 50}');
    final instructions = TextEditingController(text: event?.specialInstructions ?? '');
    var type = event?.type ?? 'wedding';
    var eventAt = event?.eventAt ?? DateTime.now().add(const Duration(days: 7, hours: 12));
    var saving = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(event == null ? 'Add event' : 'Edit event', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Event name', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Event type', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'wedding', child: Text('Wedding')),
                    DropdownMenuItem(value: 'birthday', child: Text('Birthday')),
                    DropdownMenuItem(value: 'housewarming', child: Text('Housewarming')),
                    DropdownMenuItem(value: 'corporate', child: Text('Corporate')),
                    DropdownMenuItem(value: 'engagement', child: Text('Engagement')),
                    DropdownMenuItem(value: 'reception', child: Text('Reception')),
                    DropdownMenuItem(value: 'naming_ceremony', child: Text('Naming Ceremony')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) => setState(() => type = value ?? 'other'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: const Text('Event date and time'),
                  subtitle: Text(DateFormat('EEE, d MMM yyyy • h:mm a').format(eventAt)),
                  onTap: () async {
                    final date = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)), initialDate: eventAt);
                    if (date == null || !context.mounted) return;
                    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(eventAt));
                    if (time == null) return;
                    setState(() => eventAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                  },
                ),
                TextField(controller: venue, decoration: const InputDecoration(labelText: 'Venue', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: guests, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Guest count', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: instructions, maxLines: 3, decoration: const InputDecoration(labelText: 'Special instructions', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            setState(() => saving = true);
                            try {
                              await ref.read(customerEventsProvider.notifier).save(CustomerEvent(
                                    id: event?.id ?? '',
                                    name: name.text,
                                    type: type,
                                    eventAt: eventAt,
                                    venueName: venue.text,
                                    guestCount: int.tryParse(guests.text) ?? 1,
                                    specialInstructions: instructions.text,
                                  ));
                              if (sheetContext.mounted) Navigator.pop(sheetContext);
                            } catch (error) {
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
                              setState(() => saving = false);
                            }
                          },
                    child: saving ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save event'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    name.dispose();
    venue.dispose();
    guests.dispose();
    instructions.dispose();
  }
}
