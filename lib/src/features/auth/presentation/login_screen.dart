import 'dart:async';

import 'package:bookmyplatter/src/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final phoneController = TextEditingController();
  final otpController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  Timer? resendTimer;
  bool otpSent = false;
  bool loading = false;
  int resendSeconds = 0;

  String get phoneNumber => '+91${phoneController.text.replaceAll(RegExp(r'\D'), '')}';

  @override
  void dispose() {
    resendTimer?.cancel();
    phoneController.dispose();
    otpController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void startResendTimer() {
    resendTimer?.cancel();
    setState(() => resendSeconds = 30);
    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (resendSeconds <= 1) {
        timer.cancel();
        setState(() => resendSeconds = 0);
      } else {
        setState(() => resendSeconds--);
      }
    });
  }

  Future<bool> run(Future<void> Function() action, {bool navigate = false}) async {
    if (loading) return false;
    setState(() => loading = true);
    try {
      await action();
      if (navigate && mounted) context.go('/home');
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_messageFor(error))),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> sendOtp() async {
    if (phoneController.text.replaceAll(RegExp(r'\D'), '').length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 10-digit mobile number')),
      );
      return;
    }
    final sent = await run(() => ref.read(authRepositoryProvider).signInWithOtp(phoneNumber));
    if (!mounted || !sent) return;
    setState(() => otpSent = true);
    startResendTimer();
  }

  Future<void> verifyOtp() async {
    if (otpController.text.trim().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit OTP')),
      );
      return;
    }
    await run(
      () => ref.read(authRepositoryProvider).verifyPhoneOtp(
            phone: phoneNumber,
            token: otpController.text.trim(),
          ),
      navigate: true,
    );
  }

  String _messageFor(Object error) {
    final message = error.toString();
    if (message.contains('rate limit')) return 'Too many attempts. Please wait and try again.';
    if (message.contains('invalid') || message.contains('expired')) return 'The OTP is invalid or has expired.';
    if (message.contains('SMS') || message.contains('hook') || message.contains('provider')) {
      return 'SMS OTP is not configured in this environment. Configure the Supabase Fast2SMS hook and retry.';
    }
    return 'Authentication failed. Check your connection and try again.';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (_, next) {
      final session = next.valueOrNull?.session;
      if (session != null && context.mounted) context.go('/home');
    });
    final auth = ref.watch(authRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Welcome back', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            TextField(
              controller: phoneController,
              enabled: !loading && !otpSent,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              maxLength: 10,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                border: OutlineInputBorder(),
                prefixText: '+91 ',
              ),
            ),
            if (otpSent) ...[
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: 6,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'One-time password',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => verifyOtp(),
              ),
              FilledButton(
                onPressed: loading ? null : verifyOtp,
                child: loading
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Verify OTP'),
              ),
              TextButton(
                onPressed: loading || resendSeconds > 0 ? null : sendOtp,
                child: Text(resendSeconds > 0 ? 'Resend OTP in ${resendSeconds}s' : 'Resend OTP'),
              ),
              TextButton(
                onPressed: loading
                    ? null
                    : () => setState(() {
                          otpSent = false;
                          otpController.clear();
                          resendTimer?.cancel();
                          resendSeconds = 0;
                        }),
                child: const Text('Change phone number'),
              ),
            ] else
              FilledButton(
                onPressed: loading ? null : sendOtp,
                child: loading
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Continue with OTP'),
              ),
            const Divider(height: 40),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: loading
                  ? null
                  : () => run(
                        () => auth.signInWithEmail(
                          email: emailController.text.trim(),
                          password: passwordController.text,
                        ),
                        navigate: true,
                      ),
              icon: const Icon(Icons.email_outlined),
              label: const Text('Continue with email'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: loading
                  ? null
                  : () => run(
                        () => auth.resetPassword(emailController.text.trim()),
                      ),
              child: const Text('Forgot password? Send reset link'),
            ),
            OutlinedButton.icon(
              onPressed: loading ? null : () => run(auth.signInWithGoogle),
              icon: const Icon(Icons.g_mobiledata),
              label: const Text('Continue with Google'),
            ),
          ],
        ),
      ),
    );
  }
}
