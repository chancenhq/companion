import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    required this.onContinue,
  });

  final VoidCallback onContinue;

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _sent = false;

  Future<void> _resend() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.resendEmailVerification();
    if (!mounted) return;
    setState(() => _sent = success);
  }

  Future<void> _useDifferentEmail() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 2),
                  Center(
                    child: SvgPicture.asset(
                      'assets/images/companion-logo.svg',
                      width: 64,
                      height: 64,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Verify your email',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We sent a verification link to ${authProvider.user?.email ?? 'your email address'}. Verify once to unlock your Chancen Account and transactions.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  if (_sent) ...[
                    const SizedBox(height: 16),
                    Text(
                      'A new verification email has been sent.',
                      style: TextStyle(color: colorScheme.primary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (authProvider.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      authProvider.errorMessage!,
                      style: TextStyle(color: colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const Spacer(flex: 3),
                  FilledButton(
                    onPressed: authProvider.isLoading ? null : _resend,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: authProvider.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Resend verification email'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: widget.onContinue,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Continue to assistant'),
                  ),
                  TextButton(
                    onPressed: authProvider.isLoading ? null : _useDifferentEmail,
                    child: const Text('Use a different email'),
                  ),
                  const SizedBox(height: 32),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
