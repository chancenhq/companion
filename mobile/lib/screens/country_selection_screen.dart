import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../models/chancen_country.dart';
import '../providers/auth_provider.dart';
import '../services/api_config.dart';
import '../services/countries_service.dart';
import '../services/preferences_service.dart';
import 'web_page_screen.dart';

class CountrySelectionScreen extends StatefulWidget {
  const CountrySelectionScreen({
    super.key,
    required this.onComplete,
    this.showLogo = true,
  });

  final VoidCallback onComplete;
  final bool showLogo;

  @override
  State<CountrySelectionScreen> createState() => _CountrySelectionScreenState();
}

class _CountrySelectionScreenState extends State<CountrySelectionScreen> {
  static const _consentVersion = '1.0';

  final _countriesService = CountriesService();
  List<ChancenCountry> _countries = const [];
  ChancenCountry? _selectedCountry;
  bool _consentChecked = false;
  bool _loadingCountries = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    final countries = await _countriesService.getCountries();
    if (!mounted) return;
    setState(() {
      _countries = countries;
      _loadingCountries = false;
    });
  }

  Future<void> _complete() async {
    final country = _selectedCountry;
    if (country == null || !_consentChecked || _saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final saved = authProvider.isAuthenticated
        ? await authProvider.updateCountry(country.code)
        : true;

    if (!mounted) return;

    if (!saved) {
      setState(() {
        _saving = false;
        _error = authProvider.errorMessage ?? 'Could not save your country. Please try again.';
      });
      return;
    }

    final prefs = PreferencesService.instance;
    await prefs.setUserCountry(country.name);
    await prefs.setUserCountryCode(country.code);
    await prefs.setConsent(version: _consentVersion);
    await prefs.setOnboardingComplete(true);

    if (!mounted) return;
    widget.onComplete();
  }

  void _openUrl(Uri uri, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WebPageScreen(url: uri.toString(), title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _selectedCountry;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              if (widget.showLogo) ...[
                SvgPicture.asset(
                  'assets/images/companion-logo.svg',
                  width: 64,
                  height: 64,
                ),
                const SizedBox(height: 32),
              ],
              Text(
                'Choose your country',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This helps us show the right legal pages and Chancen team for you.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_loadingCountries)
                const Center(child: CircularProgressIndicator())
              else
                ..._countries.map((country) {
                  final isSelected = selected?.code == country.code;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCountry = country),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
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
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle, size: 18, color: colorScheme.primary),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 20),
              Text(
                'Review the legal pages for your selected country.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: selected == null
                        ? null
                        : () => _openUrl(selected.privacyUri(ApiConfig.baseUrl), 'Privacy Policy'),
                    child: const Text('Privacy Policy'),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: selected == null
                        ? null
                        : () => _openUrl(selected.termsUri(ApiConfig.baseUrl), 'Terms of Use'),
                    child: const Text('Terms of Use'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: selected == null
                    ? null
                    : () => setState(() => _consentChecked = !_consentChecked),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _consentChecked,
                      onChanged: selected == null
                          ? null
                          : (value) => setState(() => _consentChecked = value ?? false),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'I have read and agree to the Privacy Policy and Terms of Use',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: selected != null && _consentChecked && !_saving ? _complete : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
