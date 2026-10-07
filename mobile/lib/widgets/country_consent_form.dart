import 'package:flutter/material.dart';

import '../models/chancen_country.dart';
import '../screens/web_page_screen.dart';
import '../services/api_config.dart';
import '../services/countries_service.dart';

/// Country choice plus privacy/terms consent (issue #106, Stories 1.1 and
/// 1.5). Nothing is pre-selected and Continue stays disabled until a country
/// is chosen and the terms are accepted. The legal links follow the chosen
/// country. Used by onboarding and by the one-time confirmation for members
/// who signed up before countries were stored on the server.
class CountryConsentForm extends StatefulWidget {
  const CountryConsentForm({
    super.key,
    required this.onSubmit,
    this.loadCountries,
    this.lockedCountryCode,
  });

  /// Saves the choice. Returns an error message, or null on success.
  final Future<String?> Function(String countryCode) onSubmit;

  /// Country source; defaults to GET /api/v1/countries (with a built-in
  /// fallback list when offline).
  final Future<List<ChancenCountry>> Function()? loadCountries;

  /// When non-null, pre-selects this country and disables the picker.
  /// Used when the invitation already set the user's country server-side.
  final String? lockedCountryCode;

  @override
  State<CountryConsentForm> createState() => _CountryConsentFormState();
}

class _CountryConsentFormState extends State<CountryConsentForm> {
  List<ChancenCountry>? _countries;
  String? _selectedCode;
  bool _consentChecked = false;
  bool _saving = false;
  String? _error;

  ChancenCountry? get _selected =>
      _countries?.where((c) => c.code == _selectedCode).firstOrNull;

  bool get _canContinue => _selected != null && _consentChecked && !_saving;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _locked => widget.lockedCountryCode != null;

  Future<void> _load() async {
    final loader = widget.loadCountries ?? CountriesService().getCountries;
    final countries = await loader();
    if (mounted) {
      setState(() {
        _countries = countries;
        if (_locked) _selectedCode = widget.lockedCountryCode;
      });
    }
  }

  Future<void> _submit() async {
    final code = _selectedCode;
    if (code == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSubmit(code);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = error;
    });
  }

  void _openLegal(Uri url, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WebPageScreen(url: url.toString(), title: title)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final countries = _countries;
    final selected = _selected;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Select your country',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (countries == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ...countries.map((country) {
              final isSelected = country.code == _selectedCode;
              final hidden = _locked && !isSelected;
              if (hidden) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  key: ValueKey('country-${country.code}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: (_saving || _locked) ? null : () => setState(() => _selectedCode = country.code),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary.withValues(alpha: 0.4)
                            : colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            country.name,
                            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (isSelected && _locked)
                          Icon(Icons.lock, size: 16, color: colorScheme.primary)
                        else if (isSelected)
                          Icon(Icons.check_circle, size: 18, color: colorScheme.primary),
                      ],
                    ),
                  ),
                ),
              );
            }),
          if (_locked) ...[
            const SizedBox(height: 4),
            Text(
              'Your country was set by your invitation and cannot be changed here.',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          Text(
            selected == null
                ? 'Choose your country to see its Privacy Policy and Terms of Use.'
                : 'To continue, please review and accept our terms for ${selected.name}.',
            style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: selected == null
                    ? null
                    : () => _openLegal(selected.privacyUri(ApiConfig.baseUrl), 'Privacy Policy'),
                child: const Text('Privacy Policy'),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: selected == null
                    ? null
                    : () => _openLegal(selected.termsUri(ApiConfig.baseUrl), 'Terms of Use'),
                child: const Text('Terms of Use'),
              ),
            ],
          ),
          InkWell(
            onTap: _saving ? null : () => setState(() => _consentChecked = !_consentChecked),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _consentChecked,
                  onChanged: _saving ? null : (v) => setState(() => _consentChecked = v ?? false),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'I have read and agree to the Privacy Policy and Terms of Use',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: colorScheme.error), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _canContinue ? _submit : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
