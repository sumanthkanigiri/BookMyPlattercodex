import 'package:bookmyplatter/src/features/address/application/address_controller.dart';
import 'package:bookmyplatter/src/features/assistant/application/catering_assistant_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class CateringAssistantScreen extends ConsumerStatefulWidget {
  const CateringAssistantScreen({super.key});

  @override
  ConsumerState<CateringAssistantScreen> createState() => _CateringAssistantScreenState();
}

class _CateringAssistantScreenState extends ConsumerState<CateringAssistantScreen> {
  final pageController = PageController();
  final manualAddressController = TextEditingController();
  int step = 0;

  @override
  void dispose() {
    pageController.dispose();
    manualAddressController.dispose();
    super.dispose();
  }

  void next() {
    if (step == 7) return;
    setState(() => step++);
    pageController.animateToPage(step, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  void back() {
    if (step == 0) return;
    setState(() => step--);
    pageController.animateToPage(step, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final assistant = ref.watch(cateringAssistantControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catering Assistant'),
        leading: step == 0 ? const BackButton() : IconButton(onPressed: back, icon: const Icon(Icons.arrow_back)),
      ),
      body: assistant.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (state) => Column(
          children: [
            LinearProgressIndicator(value: (step + 1) / 8),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Step ${step + 1} of 8', style: Theme.of(context).textTheme.labelLarge),
            ),
            Expanded(
              child: PageView(
                controller: pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _choices('What are you planning today?', const {
                    'birthday': 'Birthday', 'wedding': 'Wedding', 'engagement': 'Engagement',
                    'house_warming': 'Housewarming', 'baby_shower': 'Baby Shower',
                    'corporate': 'Corporate Event', 'festival': 'Festival',
                    'family_function': 'Family Function', 'custom': 'Custom Event',
                  }, state.eventType, (value) => _update(state.copyWith(eventType: value))),
                  _choices('What food do you prefer?', const {
                    'veg': 'Veg', 'non_veg': 'Non-Veg', 'both': 'Both Veg & Non-Veg',
                  }, state.foodPreference, (value) => _update(state.copyWith(foodPreference: value))),
                  _guestStep(state),
                  _dateStep(state),
                  _choices('What time is the event?', const {
                    'breakfast': 'Breakfast', 'lunch': 'Lunch',
                    'evening_snacks': 'Evening Snacks', 'dinner': 'Dinner',
                  }, state.mealTime, (value) => _update(state.copyWith(mealTime: value))),
                  _locationStep(state),
                  _budgetStep(state),
                  _recommendations(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choices(String title, Map<String, String> values, String? selected, ValueChanged<String> onSelected) =>
      ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          for (final entry in values.entries)
            Card(
              child: RadioListTile<String>(
                value: entry.key,
                groupValue: selected,
                title: Text(entry.value),
                onChanged: (value) {
                  if (value == null) return;
                  onSelected(value);
                  next();
                },
              ),
            ),
        ],
      );

  Widget _guestStep(CateringAssistantState state) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text('How many guests?', style: Theme.of(context).textTheme.headlineSmall),
            const Spacer(),
            Text('${state.guestCount}', style: Theme.of(context).textTheme.displayLarge),
            Slider(
              value: state.guestCount.toDouble(), min: 5, max: 500, divisions: 99,
              label: '${state.guestCount}',
              onChanged: (value) => _update(state.copyWith(guestCount: (value / 5).round() * 5)),
            ),
            Text(state.guestCount < 50
                ? 'We’ll prioritize Platter Box packages.'
                : 'We’ll prioritize Catering Combo packages.'),
            const Spacer(),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: next, child: const Text('Continue'))),
          ],
        ),
      );

  Widget _dateStep(CateringAssistantState state) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('When is your event?', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.calendar_month),
                label: Text(state.eventDate == null ? 'Select date' : DateFormat('EEEE, d MMMM yyyy').format(state.eventDate!)),
                onPressed: () async {
                  final now = DateTime.now();
                  final date = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 365)), initialDate: state.eventDate ?? now);
                  if (date != null) await _update(state.copyWith(eventDate: date));
                },
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: state.eventDate == null ? null : next, child: const Text('Continue')),
            ],
          ),
        ),
      );

  Widget _locationStep(CateringAssistantState state) {
    final addresses = ref.watch(addressControllerProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Where should we serve?', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        addresses.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text(error.toString()),
          data: (items) => Column(
            children: [
              for (final address in items)
                RadioListTile<String>(
                  value: address.id, groupValue: state.addressId,
                  title: Text(address.label), subtitle: Text('${address.line1}, ${address.area}'),
                  onChanged: (value) => _update(state.copyWith(addressId: value)),
                ),
            ],
          ),
        ),
        TextField(
          controller: manualAddressController,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Or enter an address', border: OutlineInputBorder()),
          onChanged: (value) => _update(state.copyWith(manualAddress: value)),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: state.addressId == null && (state.manualAddress?.trim().isEmpty ?? true) ? null : next,
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _budgetStep(CateringAssistantState state) => _choices('What is your budget?', const {
        '10000': '₹5,000–₹10,000', '20000': '₹10,000–₹20,000',
        '50000': '₹20,000–₹50,000', '10000000': '₹50,000+',
      }, state.budgetMaximum?.round().toString(), (value) {
        _update(state.copyWith(budgetMaximum: double.parse(value)));
      });

  Widget _recommendations() {
    final recommendations = ref.watch(assistantRecommendationsProvider);
    return recommendations.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
      data: (items) => items.isEmpty
          ? const Center(child: Text('No packages currently match all your requirements.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(item.name),
                    subtitle: Text('${item.cuisine} • ₹${item.pricePerGuest.toStringAsFixed(0)} per guest • ${item.rating}★'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/package/${item.id}'),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _update(CateringAssistantState state) =>
      ref.read(cateringAssistantControllerProvider.notifier).update((_) => state);
}
