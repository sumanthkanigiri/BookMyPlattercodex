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
  ProfileSettings? draft;

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(profileSettingsControllerProvider);
    ref.listen(profileSettingsControllerProvider, (_, next) {
      final value = next.valueOrNull;
      if (value != null && draft == null) {
        draft = value;
        nameController.text = value.fullName;
      }
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
          draft ??= value;
          if (nameController.text.isEmpty) nameController.text = value.fullName;
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
              const SizedBox(height: 12),
              Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
              SwitchListTile(title: const Text('Push notifications'), value: draft!.push, onChanged: (v) => setState(() => draft = draft!.copyWith(push: v))),
              SwitchListTile(title: const Text('SMS updates'), value: draft!.sms, onChanged: (v) => setState(() => draft = draft!.copyWith(sms: v))),
              SwitchListTile(title: const Text('Email updates'), value: draft!.email, onChanged: (v) => setState(() => draft = draft!.copyWith(email: v))),
              SwitchListTile(title: const Text('Offers and marketing'), value: draft!.marketing, onChanged: (v) => setState(() => draft = draft!.copyWith(marketing: v))),
              const Divider(),
              Text('Privacy', style: Theme.of(context).textTheme.titleLarge),
              SwitchListTile(
                title: const Text('Share anonymous usage analytics'),
                subtitle: const Text('Helps improve the BookMyPlatter experience'),
                value: draft!.analytics,
                onChanged: (v) => setState(() => draft = draft!.copyWith(analytics: v)),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  try {
                    await ref.read(profileSettingsControllerProvider.notifier).save(draft!);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
                  } catch (_) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to save settings')));
                  }
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save changes'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
              TextButton(
                onPressed: () => _deleteAccount(context),
                child: const Text('Delete account', style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
      ),
    );
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
