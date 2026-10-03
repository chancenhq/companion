import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// "Check your email" after an email sign-up (issue #106, Story 3.1). The
/// assistant stays usable while unverified, so the user can continue past it.
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _busy = false;
  String? _notice;

  Future<void> _resend() async {
    setState(() => _busy = true);
    final message = await context.read<AuthProvider>().resendEmailVerification();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _notice = message;
    });
  }

  Future<void> _checkVerified() async {
    setState(() => _busy = true);
    // On success the provider's user flips to verified and this screen closes.
    final verified = await context.read<AuthProvider>().refreshUser();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!verified) {
        _notice = "We haven't seen the confirmation yet. Open the link in the email, then try again.";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Center(
                child: SvgPicture.asset('assets/images/companion-logo.svg', width: 64, height: 64),
              ),
              const SizedBox(height: 32),
              Text(
                'Check your email',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'We sent a verification link to ${authProvider.user?.email ?? 'your email address'}. '
                'Verify once to see your Chancen Account and payments. You can use the assistant in the meantime.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (_notice != null) ...[
                const SizedBox(height: 16),
                Text(_notice!, style: TextStyle(color: theme.colorScheme.primary), textAlign: TextAlign.center),
              ],
              const Spacer(flex: 3),
              FilledButton(
                onPressed: _busy ? null : _checkVerified,
                style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("I've verified"),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy ? null : _resend,
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
                child: const Text('Resend email'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _busy ? null : authProvider.dismissEmailVerificationPrompt,
                child: const Text('Continue to assistant'),
              ),
              TextButton(
                onPressed: _busy ? null : authProvider.logout,
                child: const Text('Use a different email'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
