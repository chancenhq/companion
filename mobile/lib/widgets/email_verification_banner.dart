import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// Dismissible "verify your email" nudge shown at the top of the app for
/// unverified email sign-ups. Replaces the old full-screen interstitial: the
/// assistant and the rest of the app stay usable, while the Chancen Account /
/// payments data stays locked on the server until the address is verified.
class EmailVerificationBanner extends StatefulWidget {
  const EmailVerificationBanner({super.key});

  @override
  State<EmailVerificationBanner> createState() => _EmailVerificationBannerState();
}

class _EmailVerificationBannerState extends State<EmailVerificationBanner> {
  bool _busy = false;

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _resend() async {
    setState(() => _busy = true);
    final message = await context.read<AuthProvider>().resendEmailVerification();
    if (!mounted) return;
    setState(() => _busy = false);
    _notify(message);
  }

  Future<void> _checkVerified() async {
    setState(() => _busy = true);
    // On success the provider flips the user to verified and the banner hides.
    final verified = await context.read<AuthProvider>().refreshUser();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!verified) {
      _notify("We haven't seen the confirmation yet. Open the link in the email, then try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final email = context.select<AuthProvider, String?>((a) => a.user?.email);

    return Material(
      color: colorScheme.primaryContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.mark_email_unread_outlined, size: 20, color: colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verify your email to unlock your Chancen Account & payments',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (email != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'We sent a link to $email. You can keep using the assistant in the meantime.',
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _busy ? null : _checkVerified,
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                        child: _busy
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text("I've verified"),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _resend,
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                        child: const Text('Resend'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 20),
              onPressed: _busy ? null : context.read<AuthProvider>().dismissEmailVerificationPrompt,
            ),
          ],
        ),
      ),
    );
  }
}
