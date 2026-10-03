import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/preferences_service.dart';
import '../widgets/country_consent_form.dart';

/// One-time country confirmation for members the server has no country for,
/// or whose consent is for an older privacy/terms version (issue #106,
/// Story 1.5). Shown before the home screen even when already signed in.
class CountrySelectionScreen extends StatelessWidget {
  const CountrySelectionScreen({super.key});

  Future<String?> _save(BuildContext context, String countryCode) async {
    final error = await context.read<AuthProvider>().updateCountry(countryCode);
    if (error == null) {
      await PreferencesService.instance.setConsent(version: AuthProvider.consentVersion);
    }
    return error;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            SvgPicture.asset('assets/images/companion-logo.svg', width: 64, height: 64),
            const SizedBox(height: 16),
            Text(
              'Confirm your country',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'So the assistant can give you the right information and support team.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(child: CountryConsentForm(onSubmit: (code) => _save(context, code))),
          ],
        ),
      ),
    );
  }
}
