import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// Shown in place of Chancen Account data while the server locks it until the
/// email is verified (issue #106, Story 3.2).
class VerifyEmailCard extends StatefulWidget {
  const VerifyEmailCard({super.key, required this.onVerified});

  /// Called after "I've verified" confirms the email, so the screen can reload.
  final Future<void> Function() onVerified;

  @override
  State<VerifyEmailCard> createState() => _VerifyEmailCardState();
}

class _VerifyEmailCardState extends State<VerifyEmailCard> {
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
    final verified = await context.read<AuthProvider>().refreshUser();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _notice = verified ? null : "We haven't seen the confirmation yet. Open the link in the email, then try again.";
    });
    if (verified) await widget.onVerified();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = context.watch<AuthProvider>().user?.email;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.mark_email_unread_outlined, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              'Verify your email to see your Chancen Account',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              email == null
                  ? 'Open the link we emailed you, then come back here.'
                  : 'Open the link we sent to $email, then come back here.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (_notice != null) ...[
              const SizedBox(height: 12),
              Text(_notice!, style: TextStyle(color: theme.colorScheme.primary), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _checkVerified,
              child: const Text("I've verified"),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : _resend,
              child: const Text('Resend email'),
            ),
          ],
        ),
      ),
    );
  }
}
