import 'package:bookmyplatter/src/features/auth/data/auth_repository.dart';
import 'package:bookmyplatter/src/features/profile/application/profile_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final nameController = TextEditingController();
  final mobileController = TextEditingController();
  final emailController = TextEditingController();
  final cityController = TextEditingController();
  final eventPreferencesController = TextEditingController();
  final cuisinesController = TextEditingController();
  final dietaryController = TextEditingController();
  final gstController = TextEditingController();
  final companyController = TextEditingController();
  final newPasswordController = TextEditingController();
  ProfileSettings? draft;

  @override
  void dispose() {
    nameController.dispose();
    mobileController.dispose();
    emailController.dispose();
    cityController.dispose();
    eventPreferencesController.dispose();
    cuisinesController.dispose();
    dietaryController.dispose();
    gstController.dispose();
    companyController.dispose();
    newPasswordController.dispose();
    super.dispose();
  }

  void bind(ProfileSettings value) {
    draft = value;
    nameController.text = value.fullName;
    mobileController.text = value.mobile;
    emailController.text = value.email;
    cityController.text = value.city;
    eventPreferencesController.text = value.eventPreferences.join(', ');
    cuisinesController.text = value.favouriteCuisines.join(', ');
    dietaryController.text = value.dietaryPreferences.join(', ');
    gstController.text = value.gstNumber;
    companyController.text = value.companyName;
  }

  List<String> _csv(String value) => [
        for (final item in value.split(','))
          if (item.trim().isNotEmpty) item.trim(),
      ];

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(profileSettingsControllerProvider);
    ref.listen(profileSettingsControllerProvider, (_, next) {
      final value = next.valueOrNull;
      if (value != null && draft == null) bind(value);
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & settings')),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.read(profileSettingsControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ),
        data: (value) {
          if (draft == null) bind(value);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Personal details', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder()),
                onChanged: (text) => draft = draft!.copyWith(fullName: text),
              ),
              Row(
                children: [
                  Expanded(child: _textField(mobileController, 'Mobile', TextInputType.phone, (text) => draft = draft!.copyWith(mobile: text))),
                  const SizedBox(width: 12),
                  Expanded(child: _textField(emailController, 'Email', TextInputType.emailAddress, (text) => draft = draft!.copyWith(email: text))),
                ],
              ),
              const SizedBox(height: 12),
              _textField(cityController, 'City', TextInputType.text, (text) => draft = draft!.copyWith(city: text)),
              const SizedBox(height: 12),
              _textField(companyController, 'Company name', TextInputType.text, (text) => draft = draft!.copyWith(companyName: text)),
              const SizedBox(height: 12),
              _textField(gstController, 'GST number (optional)', TextInputType.text, (text) => draft = draft!.copyWith(gstNumber: text)),
              const SizedBox(height: 20),
              Text('Event preferences', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _textField(eventPreferencesController, 'Preferred event types', TextInputType.text, (text) => draft = draft!.copyWith(eventPreferences: _csv(text)), helper: 'Example: Wedding, Corporate, Birthday'),
              const SizedBox(height: 12),
              _textField(cuisinesController, 'Favourite cuisines', TextInputType.text, (text) => draft = draft!.copyWith(favouriteCuisines: _csv(text)), helper: 'Example: Hyderabadi, South Indian'),
              const SizedBox(height: 12),
              _textField(dietaryController, 'Dietary preferences', TextInputType.text, (text) => draft = draft!.copyWith(dietaryPreferences: _csv(text)), helper: 'Example: Jain, Vegan, No onion'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _DateChip(
                    label: 'Birthday',
                    value: draft!.birthday,
                    onSelected: (date) => setState(() => draft = draft!.copyWith(birthday: date)),
                    onClear: () => setState(() => draft = draft!.copyWith(clearBirthday: true)),
                  ),
                  _DateChip(
                    label: 'Anniversary',
                    value: draft!.anniversary,
                    onSelected: (date) => setState(() => draft = draft!.copyWith(anniversary: date)),
                    onClear: () => setState(() => draft = draft!.copyWith(clearAnniversary: true)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
              SwitchListTile(title: const Text('Push notifications'), value: draft!.push, onChanged: (v) => setState(() => draft = draft!.copyWith(push: v))),
              SwitchListTile(title: const Text('SMS updates'), value: draft!.sms, onChanged: (v) => setState(() => draft = draft!.copyWith(sms: v))),
              SwitchListTile(title: const Text('Email updates'), value: draft!.emailUpdates, onChanged: (v) => setState(() => draft = draft!.copyWith(emailUpdates: v))),
              SwitchListTile(title: const Text('Offers and marketing'), value: draft!.marketing, onChanged: (v) => setState(() => draft = draft!.copyWith(marketing: v))),
              const Divider(),
              Text('Security', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(controller: newPasswordController, obscureText: true, decoration: const InputDecoration(labelText: 'New password', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: _changePassword, icon: const Icon(Icons.password), label: const Text('Change password')),
              OutlinedButton.icon(onPressed: _signOutEverywhere, icon: const Icon(Icons.logout), label: const Text('Logout from all devices')),
              const Divider(),
              Text('Privacy', style: Theme.of(context).textTheme.titleLarge),
              SwitchListTile(
                title: const Text('Share anonymous usage analytics'),
                subtitle: const Text('Helps improve the BookMyPlatter experience'),
                value: draft!.analytics,
                onChanged: (v) => setState(() => draft = draft!.copyWith(analytics: v)),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('Save changes')),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
              TextButton(onPressed: () => _deleteAccount(context), child: const Text('Delete account', style: TextStyle(color: Colors.red))),
            ],
          );
        },
      ),
    );
  }

  Widget _textField(TextEditingController controller, String label, TextInputType type, ValueChanged<String> onChanged, {String? helper}) {
    return TextField(controller: controller, keyboardType: type, decoration: InputDecoration(labelText: label, helperText: helper, border: const OutlineInputBorder()), onChanged: onChanged);
  }

  Future<void> _save() async {
    try {
      await ref.read(profileSettingsControllerProvider.notifier).save(draft!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to save settings')));
    }
  }

  Future<void> _changePassword() async {
    if (newPasswordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use at least 8 characters')));
      return;
    }
    try {
      await ref.read(authRepositoryProvider).changePassword(newPasswordController.text);
      newPasswordController.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password update failed')));
    }
  }

  Future<void> _signOutEverywhere() async {
    await ref.read(authRepositoryProvider).signOutEverywhere();
    if (mounted) context.go('/login');
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account permanently?'),
        content: const Text('Your profile, saved addresses, favorites, and booking data will be removed. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep account')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(profileSettingsControllerProvider.notifier).deleteAccount();
      if (context.mounted) context.go('/login');
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account deletion failed')));
    }
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label, required this.value, required this.onSelected, required this.onClear});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final text = value == null ? label : '$label: ${value!.day}/${value!.month}/${value!.year}';
    return InputChip(
      label: Text(text),
      avatar: const Icon(Icons.event),
      onDeleted: value == null ? null : onClear,
      onPressed: () async {
        final now = DateTime.now();
        final date = await showDatePicker(
          context: context,
          firstDate: DateTime(now.year - 100),
          lastDate: DateTime(now.year + 5),
          initialDate: value ?? DateTime(now.year - 25, now.month, now.day),
        );
        if (date != null) onSelected(date);
      },
    );
  }
}
