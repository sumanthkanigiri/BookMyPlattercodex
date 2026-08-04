import 'package:bookmyplatter/src/core/errors/app_exception.dart';
import 'package:bookmyplatter/src/features/loyalty/application/loyalty_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class LoyaltyScreen extends ConsumerWidget {
  const LoyaltyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loyalty = ref.watch(loyaltyControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Rewards & referrals')),
      body: loyalty.when(
        loading: () => const _LoyaltySkeleton(),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.card_giftcard_outlined, size: 52),
              const SizedBox(height: 12),
              Text(error is AppException ? error.message : 'Unable to load rewards'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => ref.read(loyaltyControllerProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (summary) => RefreshIndicator(
          onRefresh: () => ref.read(loyaltyControllerProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF3C1285), Color(0xFF6C36B8)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('BookMyPlatter Rewards', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _Balance(label: 'Reward points', value: '${summary.points}')),
                        Expanded(child: _Balance(label: 'Wallet', value: '₹${summary.walletBalance.toStringAsFixed(0)}')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invite friends', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      const Text('Rewards are credited after your friend completes their first event.'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: SelectableText(summary.referralCode, style: Theme.of(context).textTheme.headlineSmall)),
                          FilledButton.icon(
                            onPressed: () => Share.share('Plan your event with BookMyPlatter. Use my referral code ${summary.referralCode} when you join.'),
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('Share'),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      OutlinedButton.icon(
                        onPressed: () => _applyCode(context, ref),
                        icon: const Icon(Icons.redeem_outlined),
                        label: const Text('I have a referral code'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Reward activity', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (summary.transactions.isEmpty)
                const Card(child: ListTile(leading: Icon(Icons.history), title: Text('No reward activity yet')))
              else
                for (final item in summary.transactions)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Icon(item.pointsDelta >= 0 && item.amountDelta >= 0 ? Icons.add : Icons.remove)),
                      title: Text(item.description),
                      subtitle: Text(DateFormat('d MMM yyyy, h:mm a').format(item.createdAt)),
                      trailing: Text(_transactionValue(item), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  String _transactionValue(LoyaltyTransaction transaction) {
    if (transaction.amountDelta != 0) {
      return '${transaction.amountDelta > 0 ? '+' : '-'}₹${transaction.amountDelta.abs().toStringAsFixed(0)}';
    }
    return '${transaction.pointsDelta > 0 ? '+' : ''}${transaction.pointsDelta} pts';
  }

  Future<void> _applyCode(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply referral code'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          maxLength: 16,
          decoration: const InputDecoration(labelText: 'Referral code', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Apply')),
        ],
      ),
    );
    controller.dispose();
    if (code == null || !context.mounted) return;
    try {
      await ref.read(loyaltyControllerProvider.notifier).applyReferralCode(code);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referral code applied')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error is AppException ? error.message : 'Unable to apply referral code')));
      }
    }
  }
}

class _Balance extends StatelessWidget {
  const _Balance({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)), Text(label, style: const TextStyle(color: Colors.white70))]);
}

class _LoyaltySkeleton extends StatelessWidget {
  const _LoyaltySkeleton();
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: const [Card(child: SizedBox(height: 160, child: LinearProgressIndicator())), Card(child: SizedBox(height: 180, child: LinearProgressIndicator()))]);
}
