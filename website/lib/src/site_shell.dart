import 'package:bookmyplatter/src/features/crm/application/crm_repository.dart';
import 'package:bookmyplatter/src/features/tracking/application/customer_activity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class SiteShell extends ConsumerWidget {
  const SiteShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: InkWell(
          onTap: () => context.go('/'),
          borderRadius: BorderRadius.circular(12),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.room_service_rounded, color: Color(0xFFF5B300)),
              SizedBox(width: 8),
              Text('BookMyPlatter', style: TextStyle(fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
        actions: [
          if (wide) ...[
            _Nav(label: 'Home', path: '/'),
            _Nav(label: 'Veg', path: '/packages/veg'),
            _Nav(label: 'Non-Veg', path: '/packages/non-veg'),
            _Nav(label: 'Platter Box', path: '/packages/platter-box'),
            _Nav(label: 'Combos', path: '/packages/catering-combos'),
            _Nav(label: 'About', path: '/about'),
            TextButton.icon(
              onPressed: () => _showLeadSheet(context, ref),
              icon: const Icon(Icons.call_outlined),
              label: const Text('Request callback'),
            ),
          ],
          IconButton(tooltip: 'Search', onPressed: () => context.go('/search'), icon: const Icon(Icons.search)),
          IconButton(tooltip: 'Cart', onPressed: () => context.go('/cart'), icon: const Icon(Icons.shopping_bag_outlined)),
          IconButton(tooltip: 'Account', onPressed: () => context.go('/profile'), icon: const Icon(Icons.account_circle_outlined)),
          const SizedBox(width: 12),
        ],
      ),
      drawer: wide ? null : _MobileMenu(onCallback: () => _showLeadSheet(context, ref)),
      body: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            right: 18,
            bottom: 22,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'website-ai-assistant',
                  onPressed: () {
                    ref.read(customerActivityRepositoryProvider).appOpen(pagePath: '/assistant');
                    context.go('/planner');
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('AI Assistant'),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  heroTag: 'website-call-lead',
                  backgroundColor: const Color(0xFF3C1285),
                  foregroundColor: Colors.white,
                  onPressed: () => _openCall(context, ref),
                  icon: const Icon(Icons.call),
                  label: const Text('Call'),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  heroTag: 'website-whatsapp-lead',
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  onPressed: () => _openWhatsApp(context, ref),
                  icon: const Icon(Icons.chat),
                  label: const Text('WhatsApp'),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const _Footer(),
    );
  }

  static Future<void> _openCall(BuildContext context, WidgetRef ref) async {
    ref.read(customerActivityRepositoryProvider).callClick();
    final uri = Uri.parse('tel:+919995559338');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone dialer is not available')));
    }
  }

  static Future<void> _openWhatsApp(BuildContext context, WidgetRef ref) async {
    ref.read(customerActivityRepositoryProvider).whatsappClick();
    var leadId = '';
    try {
      leadId = await ref.read(crmRepositoryProvider).recordWhatsAppClick();
    } catch (_) {
      leadId = '';
    }
    final uri = Uri.parse('https://wa.me/?text=${crmDeepLinkMessage(leadId: leadId)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WhatsApp is not available')));
    }
  }

  static Future<void> _showLeadSheet(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final mobile = TextEditingController();
    final email = TextEditingController();
    final guests = TextEditingController();
    final budget = TextEditingController();
    final location = TextEditingController();
    final notes = TextEditingController();
    final key = GlobalKey<FormState>();
    var eventType = 'wedding';
    var foodPreference = 'veg';
    var saving = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
          child: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Plan your event with BookMyPlatter', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Name'), validator: _required),
                const SizedBox(height: 12),
                TextFormField(controller: mobile, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile / WhatsApp'), validator: _phone),
                const SizedBox(height: 12),
                TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: eventType,
                  decoration: const InputDecoration(labelText: 'Event type'),
                  items: const [
                    DropdownMenuItem(value: 'wedding', child: Text('Wedding')),
                    DropdownMenuItem(value: 'birthday', child: Text('Birthday')),
                    DropdownMenuItem(value: 'corporate', child: Text('Corporate')),
                    DropdownMenuItem(value: 'house_warming', child: Text('House warming')),
                    DropdownMenuItem(value: 'food_tasting', child: Text('Food tasting')),
                  ],
                  onChanged: (value) => setState(() => eventType = value ?? 'wedding'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: foodPreference,
                  decoration: const InputDecoration(labelText: 'Food preference'),
                  items: const [
                    DropdownMenuItem(value: 'veg', child: Text('Veg')),
                    DropdownMenuItem(value: 'non_veg', child: Text('Non Veg')),
                    DropdownMenuItem(value: 'mixed', child: Text('Mixed')),
                  ],
                  onChanged: (value) => setState(() => foodPreference = value ?? 'veg'),
                ),
                const SizedBox(height: 12),
                TextFormField(controller: guests, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Guest count')),
                const SizedBox(height: 12),
                TextFormField(controller: budget, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Budget')),
                const SizedBox(height: 12),
                TextFormField(controller: location, decoration: const InputDecoration(labelText: 'Event location')),
                const SizedBox(height: 12),
                TextFormField(controller: notes, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Special requirements')),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!key.currentState!.validate()) return;
                            setState(() => saving = true);
                            try {
                              await ref.read(crmRepositoryProvider).requestCallback(
                                    name: name.text,
                                    mobile: mobile.text,
                                    email: email.text,
                                    eventType: eventType,
                                    guestCount: int.tryParse(guests.text),
                                    foodPreference: foodPreference,
                                    budget: double.tryParse(budget.text),
                                    eventLocation: location.text,
                                    notes: notes.text,
                                    source: eventType == 'food_tasting' ? 'food_tasting' : 'enquiry',
                                  );
                              if (sheetContext.mounted) Navigator.pop(sheetContext);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks. Our catering specialist will contact you.')));
                              }
                            } catch (error) {
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
                              setState(() => saving = false);
                            }
                          },
                    child: saving ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Submit enquiry'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  static String? _required(String? value) => (value?.trim().isEmpty ?? true) ? 'Required' : null;
  static String? _phone(String? value) => (value?.replaceAll(RegExp('[^0-9]'), '').length ?? 0) < 10 ? 'Enter a valid mobile number' : null;
}

class _Nav extends StatelessWidget {
  const _Nav({required this.label, required this.path});
  final String label;
  final String path;
  @override
  Widget build(BuildContext context) => TextButton(onPressed: () => context.go(path), child: Text(label));
}

class _MobileMenu extends StatelessWidget {
  const _MobileMenu({required this.onCallback});
  final VoidCallback onCallback;
  @override
  Widget build(BuildContext context) => Drawer(
        child: SafeArea(
          child: ListView(children: [
            const ListTile(title: Text('BookMyPlatter', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
            ListTile(title: const Text('Request Callback'), leading: const Icon(Icons.call_outlined), onTap: () { Navigator.pop(context); onCallback(); }),
            for (final item in const [
              ('Home', '/'), ('AI Catering Planner', '/planner'), ('Veg Packages', '/packages/veg'),
              ('Non-Veg Packages', '/packages/non-veg'), ('Platter Box', '/packages/platter-box'),
              ('Catering Combos', '/packages/catering-combos'), ('My Orders', '/orders'),
              ('Saved Addresses', '/addresses'), ('Contact Us', '/contact'), ('FAQ', '/faq'),
            ])
              ListTile(title: Text(item.$1), onTap: () { Navigator.pop(context); context.go(item.$2); }),
          ]),
        ),
      );
}

class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF281052),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 20, runSpacing: 8, children: [
              const Text('© BookMyPlatter • Premium catering', style: TextStyle(color: Colors.white)),
              Wrap(spacing: 8, children: [
                TextButton(onPressed: () => context.go('/privacy'), child: const Text('Privacy', style: TextStyle(color: Colors.white))),
                TextButton(onPressed: () => context.go('/terms'), child: const Text('Terms', style: TextStyle(color: Colors.white))),
                TextButton(onPressed: () => context.go('/contact'), child: const Text('Contact', style: TextStyle(color: Colors.white))),
              ]),
            ]),
          ),
        ),
      );
}
