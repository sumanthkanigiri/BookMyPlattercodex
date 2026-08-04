import 'package:bookmyplatter/src/features/crm/application/crm_repository.dart';
import 'package:bookmyplatter/src/features/support/application/support_controller.dart';
import 'package:bookmyplatter/src/features/tracking/application/customer_activity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contact = ref.watch(supportContactProvider);
    final questions = ref.watch(frequentlyAskedQuestionsProvider);
    final tickets = ref.watch(supportTicketsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Help & support')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(supportContactProvider);
          ref.invalidate(frequentlyAskedQuestionsProvider);
          ref.invalidate(supportTicketsProvider);
          await ref.read(frequentlyAskedQuestionsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('How can we help?', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            contact.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _RetryCard(
                message: 'Support contacts are unavailable',
                onRetry: () => ref.invalidate(supportContactProvider),
              ),
              data: (details) => Row(
                children: [
                  Expanded(
                    child: _ContactButton(
                      icon: Icons.chat,
                      label: 'WhatsApp',
                      onPressed: () async {
                        ref.read(customerActivityRepositoryProvider).whatsappClick();
                        var leadId = '';
                        try {
                          leadId = await ref
                              .read(crmRepositoryProvider)
                              .recordWhatsAppClick();
                        } catch (_) {
                          leadId = '';
                        }
                        if (!context.mounted) return;
                        await _open(
                          context,
                          Uri.parse(
                            'https://wa.me/${_digits(details.whatsapp)}'
                            '?text=${crmDeepLinkMessage(leadId: leadId)}',
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ContactButton(
                      icon: Icons.call_outlined,
                      label: 'Call',
                      onPressed: () {
                        ref.read(customerActivityRepositoryProvider).callClick();
                        _open(context, Uri(scheme: 'tel', path: details.phone));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _ContactButton(icon: Icons.email_outlined, label: 'Email', onPressed: () => _open(context, Uri(scheme: 'mailto', path: details.email)))),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Frequently asked questions', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            questions.when(
              loading: () => const _FaqSkeleton(),
              error: (error, _) => _RetryCard(message: 'Could not load FAQs', onRetry: () => ref.invalidate(frequentlyAskedQuestionsProvider)),
              data: (items) => items.isEmpty
                  ? const Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('No FAQs are currently published')))
                  : Column(children: [for (final item in items) Card(child: ExpansionTile(title: Text(item.question), children: [Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Align(alignment: Alignment.centerLeft, child: Text(item.answer)))]])),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Text('Your tickets', style: Theme.of(context).textTheme.titleLarge)),
                FilledButton.icon(onPressed: () => _showTicketForm(context, ref), icon: const Icon(Icons.add), label: const Text('New ticket')),
              ],
            ),
            const SizedBox(height: 8),
            tickets.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _RetryCard(message: 'Could not load tickets', onRetry: () => ref.invalidate(supportTicketsProvider)),
              data: (items) => items.isEmpty
                  ? const Card(child: ListTile(leading: Icon(Icons.support_agent), title: Text('No support tickets yet')))
                  : Column(children: [for (final item in items) Card(child: ListTile(leading: const Icon(Icons.confirmation_number_outlined), title: Text(item.subject), subtitle: Text(DateFormat('d MMM yyyy, h:mm a').format(item.createdAt)), trailing: Chip(label: Text(item.status.replaceAll('_', ' ')))))]),
            ),
          ],
        ),
      ),
    );
  }

  static String _digits(String value) => value.replaceAll(RegExp('[^0-9]'), '');

  static Future<void> _open(BuildContext context, Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No compatible app is available')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the requested support channel')));
      }
    }
  }

  static Future<void> _showTicketForm(BuildContext context, WidgetRef ref) async {
    final subject = TextEditingController();
    final message = TextEditingController();
    final key = GlobalKey<FormState>();
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
                Text('Raise a support ticket', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                TextFormField(controller: subject, maxLength: 120, decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()), validator: (value) => (value?.trim().length ?? 0) < 5 ? 'Enter at least 5 characters' : null),
                const SizedBox(height: 12),
                TextFormField(controller: message, minLines: 4, maxLines: 8, maxLength: 2000, decoration: const InputDecoration(labelText: 'How can we help?', border: OutlineInputBorder()), validator: (value) => (value?.trim().length ?? 0) < 10 ? 'Enter at least 10 characters' : null),
                SizedBox(width: double.infinity, child: FilledButton(
                  onPressed: saving ? null : () async {
                    if (!key.currentState!.validate()) return;
                    setState(() => saving = true);
                    try {
                      await ref.read(supportRepositoryProvider).createTicket(subject: subject.text, message: message.text);
                      ref.invalidate(supportTicketsProvider);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    } catch (error) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
                      setState(() => saving = false);
                    }
                  },
                  child: saving ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Submit ticket'),
                )),
              ]),
            ),
          ),
        ),
      ),
    );
    subject.dispose();
    message.dispose();
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Card(child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onPressed, child: Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: Column(children: [Icon(icon), const SizedBox(height: 8), Text(label)]))));
}

class _RetryCard extends StatelessWidget {
  const _RetryCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(title: Text(message), trailing: IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh))));
}

class _FaqSkeleton extends StatelessWidget {
  const _FaqSkeleton();
  @override
  Widget build(BuildContext context) => const Column(children: [Card(child: SizedBox(height: 64, child: LinearProgressIndicator())), Card(child: SizedBox(height: 64, child: LinearProgressIndicator()))]);
}
