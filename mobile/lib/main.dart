import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/accounts_provider.dart';
import 'providers/categories_provider.dart';
import 'providers/merchants_provider.dart';
import 'providers/tags_provider.dart';
import 'providers/transactions_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/my_account_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/privacy_provider.dart';
import 'screens/backend_config_screen.dart';
import 'screens/country_selection_screen.dart';
import 'screens/login_screen.dart';
import 'screens/biometric_lock_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/sso_onboarding_screen.dart';
import 'services/api_config.dart';
import 'services/connectivity_service.dart';
import 'services/log_service.dart';
import 'services/preferences_service.dart';
import 'services/telemetry_service.dart';
import 'theme/sure_theme.dart';
import 'l10n/app_localizations.dart';
import 'package:upgrader/upgrader.dart';

/// Chancen brand green. Layered over companion-new's SureTheme so the design
/// system stays intact but the brand/accent reads as Chancen on mobile.
const Color _chancenGreen = Color(0xFF62A446);

/// Re-skins a SureTheme [ThemeData] with the Chancen green brand: primary
/// accent (send button, switches, progress), the FAB, and primary buttons.
/// In dark mode it also applies Chancen's "darker than black" surfaces so the
/// theme reads as near-pure black (companion's original dark look) with no
/// green surface tint. Disabled states fall back to Material defaults.
ThemeData _chancenBranded(ThemeData base) {
  WidgetStateProperty<Color?> brandUnlessDisabled(Color color) {
    return WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled) ? null : color,
    );
  }

  final isDark = base.brightness == Brightness.dark;

  var scheme = base.colorScheme.copyWith(
    primary: _chancenGreen,
    onPrimary: Colors.white,
    // Material 3 tints elevated surfaces with `primary`; a green primary
    // otherwise leaves a green cast on dark surfaces. Keep surfaces flat.
    surfaceTint: Colors.transparent,
  );

  if (isDark) {
    // Chancen "darker than black" dark surfaces (commit #13 / #25).
    scheme = scheme.copyWith(
      surface: const Color(0xFF030303),
      surfaceContainerLowest: const Color(0xFF000000),
      surfaceContainerLow: const Color(0xFF030303),
      surfaceContainer: const Color(0xFF070707),
      surfaceContainerHigh: const Color(0xFF0A0A0A),
      surfaceContainerHighest: const Color(0xFF0E0E0E),
      onSurface: const Color(0xFFF0F0F0),
      onSurfaceVariant: const Color(0xFFC0C0C0),
    );
  }

  var themed = base.copyWith(
    colorScheme: scheme,
    floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
      backgroundColor: _chancenGreen,
      foregroundColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: (base.elevatedButtonTheme.style ?? const ButtonStyle()).copyWith(
        backgroundColor: brandUnlessDisabled(_chancenGreen),
        foregroundColor: brandUnlessDisabled(Colors.white),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: (base.filledButtonTheme.style ?? const ButtonStyle()).copyWith(
        backgroundColor: brandUnlessDisabled(_chancenGreen),
        foregroundColor: brandUnlessDisabled(Colors.white),
      ),
    ),
  );

  if (isDark) {
    // SureTheme pins these to its dark grey; black them out to match companion.
    themed = themed.copyWith(
      scaffoldBackgroundColor: const Color(0xFF030303),
      appBarTheme: themed.appBarTheme.copyWith(
        backgroundColor: const Color(0xFF030303),
      ),
      cardTheme: themed.cardTheme.copyWith(color: const Color(0xFF070707)),
      inputDecorationTheme: themed.inputDecorationTheme.copyWith(
        fillColor: const Color(0xFF0A0A0A),
      ),
    );
  }

  return themed;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.initialize();

  // Add initial log entry
  LogService.instance.info('App', 'Chancen Companion starting...');

  // Read the privacy preference before the first frame so money values are
  // never briefly rendered unmasked for a user who enabled "Hide amounts".
  // Default to masked (fail-closed) if it can't be read.
  bool moneyHidden = true;
  try {
    moneyHidden = await PreferencesService.instance.getMoneyHidden();
  } catch (e) {
    LogService.instance.warning(
      'App',
      'Failed to read privacy preference at startup with ${e.runtimeType}',
    );
  }

  await TelemetryService.instance.initialize(
    appRunner: () => runApp(SureApp(moneyHidden: moneyHidden)),
  );
}

class SureApp extends StatelessWidget {
  // Fail-closed default (masked) for the no-argument path; main() always passes
  // the persisted value explicitly.
  const SureApp({super.key, this.moneyHidden = true});

  /// The persisted "hide amounts" state, read before `runApp` (see `main`).
  final bool moneyHidden;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LogService.instance),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => MyAccountProvider()),
        ChangeNotifierProvider(create: (_) => CategoriesProvider()),
        ChangeNotifierProvider(create: (_) => MerchantsProvider()),
        ChangeNotifierProvider(create: (_) => TagsProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
            create: (_) => PrivacyProvider(initialHidden: moneyHidden)),
        ChangeNotifierProxyProvider<ConnectivityService, AccountsProvider>(
          create: (_) => AccountsProvider(),
          update: (_, connectivityService, accountsProvider) {
            if (accountsProvider == null) {
              final provider = AccountsProvider();
              provider.setConnectivityService(connectivityService);
              return provider;
            } else {
              accountsProvider.setConnectivityService(connectivityService);
              return accountsProvider;
            }
          },
        ),
        ChangeNotifierProxyProvider<ConnectivityService, TransactionsProvider>(
          create: (_) => TransactionsProvider(),
          update: (_, connectivityService, transactionsProvider) {
            if (transactionsProvider == null) {
              final provider = TransactionsProvider();
              provider.setConnectivityService(connectivityService);
              return provider;
            } else {
              transactionsProvider.setConnectivityService(connectivityService);
              return transactionsProvider;
            }
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          debugShowCheckedModeBanner: false,
          navigatorObservers: TelemetryService.instance.navigatorObservers,
          theme: _chancenBranded(SureTheme.light),
          darkTheme: _chancenBranded(SureTheme.dark),
          themeMode: themeProvider.themeMode,
          routes: {
            '/config': (context) => const BackendConfigScreen(),
            '/login': (context) => const LoginScreen(),
            '/home': (context) => const MainNavigationScreen(),
          },
          home: const AppWrapper(),
        ),
      ),
    );
  }
}

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> with WidgetsBindingObserver {
  bool _isCheckingConfig = true;
  bool _hasBackendUrl = false;
  bool _isLocked = false;
  bool _onboardingComplete = true; // assume complete until checked (no flash)
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  final _upgrader = Upgrader(
    durationUntilAlertAgain: const Duration(days: 7),
    countryCode: 'us',
    messages: _SureUpgraderMessages(),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBackendConfig();
    _checkOnboarding();
    _initDeepLinks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _markLockedIfEnabled();
    } else if (state == AppLifecycleState.resumed && _isLocked) {
      // Lock screen is already showing via build(); biometric auto-triggers there.
    }
  }

  Future<void> _markLockedIfEnabled() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) return;
    final enabled = await PreferencesService.instance.getBiometricEnabled();
    if (enabled && mounted) {
      setState(() => _isLocked = true);
    }
  }

  void _onUnlocked() {
    if (mounted) setState(() => _isLocked = false);
  }

  Future<void> _onLockLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (mounted) setState(() => _isLocked = false);
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    // Handle deep link that launched the app (cold start)
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        TelemetryService.instance.addBreadcrumb(
          'deep_links',
          'initial_link_received',
          data: {'recognized': _isSsoCallback(uri)},
        );
        _handleDeepLink(uri);
      }
    }).catchError((e, stackTrace) {
      LogService.instance.error(
        'DeepLinks',
        'Initial link failed with ${e.runtimeType}',
      );
      unawaited(TelemetryService.instance.captureHandledException(
        e,
        stackTrace,
        operation: 'deep_links.initial_link',
      ));
    });

    // Listen for deep links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) => _handleDeepLink(uri),
      onError: (e, stackTrace) {
        LogService.instance.error(
          'DeepLinks',
          'Link stream failed with ${e.runtimeType}',
        );
        unawaited(TelemetryService.instance.captureHandledException(
          e,
          stackTrace,
          operation: 'deep_links.stream',
        ));
      },
    );
  }

  void _handleDeepLink(Uri uri) {
    final isSsoCallback = _isSsoCallback(uri);
    TelemetryService.instance.addBreadcrumb(
      'deep_links',
      'link_received',
      data: {'recognized': isSsoCallback},
    );

    if (isSsoCallback) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.handleSsoCallback(uri);
    }
  }

  bool _isSsoCallback(Uri uri) =>
      uri.scheme == 'sureapp' && uri.host == 'oauth';

  Future<void> _checkBackendConfig() async {
    final hasUrl = await TelemetryService.instance.traceAsync(
      'app.backend_config_check',
      'Backend configuration check',
      ApiConfig.initialize,
    );
    TelemetryService.instance.addBreadcrumb(
      'app',
      'backend_config_checked',
      data: {'configured': hasUrl},
    );
    if (mounted) {
      setState(() {
        _hasBackendUrl = hasUrl;
        _isCheckingConfig = false;
      });
    }
  }

  Future<void> _checkOnboarding() async {
    // The country now lives on the server; drop the old on-device guess.
    await PreferencesService.instance.clearLegacyUserCountry();
    final complete = await PreferencesService.instance.getOnboardingComplete();
    if (mounted) {
      setState(() => _onboardingComplete = complete);
    }
  }

  void _onOnboardingComplete() {
    setState(() => _onboardingComplete = true);
  }

  void _onBackendConfigSaved() {
    setState(() {
      _hasBackendUrl = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingConfig) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_hasBackendUrl) {
      return BackendConfigScreen(
        onConfigSaved: _onBackendConfigSaved,
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Only show loading spinner during initial auth check
        if (authProvider.isInitializing) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // SSO callbacks must win over everything — including first-launch
        // onboarding — so the deep link is never dropped from the widget tree.
        if (authProvider.ssoOnboardingPending) {
          return const SsoOnboardingScreen();
        }

        // Onboarding (country select + consent) must complete before the app
        // is accessible, even when the user signed up on page 1 of the flow.
        if (!_onboardingComplete) {
          return OnboardingScreen(
            onComplete: _onOnboardingComplete,
            initialPage: authProvider.isAuthenticated ? 2 : 0,
          );
        }

        if (authProvider.isAuthenticated) {
          // Members accept the privacy/terms for their country once.
          if (authProvider.countryConfirmationRequired) {
            return const CountrySelectionScreen();
          }

          // SSO users must set a password before they can be locked out.
          if (authProvider.user?.hasPassword == false) {
            return const SsoOnboardingScreen(passwordOnlyMode: true);
          }

          return Stack(
            children: [
              UpgradeAlert(
                upgrader: _upgrader,
                showIgnore: false,
                child: const MainNavigationScreen(),
              ),
              if (_isLocked)
                BiometricLockScreen(
                  onUnlocked: _onUnlocked,
                  onLogout: _onLockLogout,
                ),
            ],
          );
        }

        // Clear stale lock state so it doesn't flash on the next login.
        if (_isLocked) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _isLocked = false);
          });
        }

        return const LoginScreen();
      },
    );
  }
}

class _SureUpgraderMessages extends UpgraderMessages {
  @override
  String get title => 'Update available';

  @override
  String get body =>
      '{{appName}} {{currentAppStoreVersion}} is now available â€” '
      'you have {{currentInstalledVersion}}.\n\n'
      "What's new? Check the store for release notes.";

  @override
  String get buttonTitleUpdate => 'Update now';

  @override
  String get buttonTitleLater => 'Later';

  @override
  String get releaseNotes => '';
}
