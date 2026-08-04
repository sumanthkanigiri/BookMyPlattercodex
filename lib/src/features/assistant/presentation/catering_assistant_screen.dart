import 'package:bookmyplatter/src/features/address/application/address_controller.dart';
import 'package:bookmyplatter/src/features/assistant/application/catering_assistant_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Catering Assistant', style: TextStyle(fontWeight: FontWeight.w700)),
            Text('Powered by your preferences', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        leading: step == 0 ? const BackButton() : IconButton(onPressed: back, icon: const Icon(Icons.arrow_back)),
      ),
      body: assistant.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (state) => Column(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (step + 1) / 8),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: const Color(0xFFE9E1F7),
                color: const Color(0xFFF5B300),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  _AssistantAvatar(step: step),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18).copyWith(bottomLeft: const Radius.circular(4)),
                        boxShadow: const [BoxShadow(color: Color(0x183C1285), blurRadius: 18, offset: Offset(0, 6))],
                      ),
                      child: Text(_assistantMessage(step), style: Theme.of(context).textTheme.bodyLarge),
                    ),
                  ),
                ],
              ),
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
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          for (final entry in values.entries)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: selected == entry.key ? const Color(0xFFF0E9FC) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected == entry.key ? const Color(0xFF3C1285) : const Color(0xFFE8E3F0),
                  width: selected == entry.key ? 2 : 1,
                ),
                boxShadow: const [BoxShadow(color: Color(0x123C1285), blurRadius: 14, offset: Offset(0, 5))],
              ),
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
    final plan = ref.watch(aiCateringPlanProvider);
    return recommendations.when(
      loading: () => const _RecommendationSkeleton(),
      error: (error, _) => Center(child: Text(error.toString())),
      data: (items) => items.isEmpty
          ? const Center(child: Text('No packages currently match all your requirements.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return _AiPlanCard(plan: plan);
                final item = items[index - 1];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          if (item.imageUrl != null)
                            CachedNetworkImage(
                              imageUrl: item.imageUrl!, height: 190, width: double.infinity, fit: BoxFit.cover,
                              placeholder: (_, __) => Container(height: 190, color: const Color(0xFFEDE7F6)),
                              errorWidget: (_, __, ___) => const _FoodImageFallback(),
                            )
                          else
                            const _FoodImageFallback(),
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Chip(
                              avatar: const Icon(Icons.auto_awesome, size: 16),
                              label: Text(index == 1 ? 'Best match' : 'Recommended'),
                              backgroundColor: const Color(0xFFF5B300),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(item.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
                                _FoodBadge(isVeg: item.isVeg),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('${item.cuisine} • ${item.rating.toStringAsFixed(1)} ★ • ${item.minGuests}+ guests'),
                            const SizedBox(height: 8),
                            Text('₹${item.pricePerGuest.toStringAsFixed(0)} per plate', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: const Color(0xFF3C1285), fontWeight: FontWeight.w700)),
                            if (item.menuItems.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(item.menuItems.take(3).join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(child: OutlinedButton(onPressed: () => context.go('/package/${item.id}'), child: const Text('Customize'))),
                                const SizedBox(width: 10),
                                Expanded(child: FilledButton(onPressed: () => context.go('/package/${item.id}'), child: const Text('Book now'))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _update(CateringAssistantState state) =>
      ref.read(cateringAssistantControllerProvider.notifier).update((_) => state);

  String _assistantMessage(int currentStep) => const [
        'Hi! I’ll help you plan the perfect catering experience.',
        'Great choice. Now tell me your food preference.',
        'How many guests should we prepare for?',
        'Let’s reserve the right date for your event.',
        'Which meal should the menu be designed around?',
        'Where would you like BookMyPlatter to serve?',
        'One last detail—what budget feels comfortable?',
        'I found the strongest matches from our live menu.',
      ][currentStep];
}

class _AiPlanCard extends StatelessWidget {
  const _AiPlanCard({required this.plan});
  final AsyncValue<AiCateringPlan?> plan;

  @override
  Widget build(BuildContext context) => plan.when(
        loading: () => const Card(child: Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator())),
        error: (error, _) => Card(child: ListTile(leading: const Icon(Icons.auto_awesome), title: const Text('AI plan unavailable'), subtitle: Text(error.toString()))),
        data: (item) {
          if (item == null) return const SizedBox.shrink();
          final serving = item.servingPlan;
          final guestEstimate = item.guestEstimate;
          return Card(
            color: const Color(0xFFF7F1FF),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [const Icon(Icons.auto_awesome, color: Color(0xFF3C1285)), const SizedBox(width: 8), Text('AI catering plan', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))]),
                const SizedBox(height: 12),
                Text(item.bestPackage['reason'] as String? ?? 'Package, budget, guest count, and menu recommendations are generated from the live BookMyPlatter catalog.'),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  Chip(label: Text('Buffered guests: ${guestEstimate['recommended_buffer_guests'] ?? '-'}')),
                  Chip(label: Text('Starters: ${serving['starters'] ?? '-'}')),
                  Chip(label: Text('Mains: ${serving['mains'] ?? '-'}')),
                  Chip(label: Text('Desserts: ${serving['desserts'] ?? '-'}')),
                  Chip(label: Text('Staff: ${serving['service_staff'] ?? '-'}')),
                ]),
                const SizedBox(height: 12),
                Text(item.festivalRecommendation),
                const SizedBox(height: 8),
                Text(item.supportAnswer, style: Theme.of(context).textTheme.bodyMedium),
                if (item.faq.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final faq in item.faq.take(2)) ListTile(contentPadding: EdgeInsets.zero, dense: true, leading: const Icon(Icons.help_outline), title: Text(faq['question'] as String? ?? ''), subtitle: Text(faq['answer'] as String? ?? '')),
                ],
              ]),
            ),
          );
        },
      );
}

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: CircleAvatar(
          key: ValueKey(step),
          radius: 27,
          backgroundColor: const Color(0xFF3C1285),
          child: Icon(const [Icons.celebration, Icons.restaurant, Icons.groups, Icons.calendar_month, Icons.schedule, Icons.location_on, Icons.currency_rupee, Icons.auto_awesome][step], color: Colors.white),
        ),
      );
}

class _FoodBadge extends StatelessWidget {
  const _FoodBadge({required this.isVeg});
  final bool isVeg;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isVeg ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(isVeg ? 'VEG' : 'NON-VEG', style: TextStyle(color: isVeg ? Colors.green.shade800 : Colors.red.shade800, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}

class _FoodImageFallback extends StatelessWidget {
  const _FoodImageFallback();
  @override
  Widget build(BuildContext context) => Container(
        height: 190,
        width: double.infinity,
        color: const Color(0xFFEDE7F6),
        alignment: Alignment.center,
        child: const Icon(Icons.restaurant_menu, size: 64, color: Color(0xFF3C1285)),
      );
}

class _RecommendationSkeleton extends StatelessWidget {
  const _RecommendationSkeleton();
  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (_, __) => Card(
          child: Column(
            children: [
              Container(height: 170, color: const Color(0xFFEDE7F6)),
              const Padding(
                padding: EdgeInsets.all(18),
                child: LinearProgressIndicator(backgroundColor: Color(0xFFEDE7F6)),
              ),
            ],
          ),
        ),
      );
}
