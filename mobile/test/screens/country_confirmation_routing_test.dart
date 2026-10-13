import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sure_mobile/main.dart';
import 'package:sure_mobile/models/user.dart';
import 'package:sure_mobile/providers/app_config_provider.dart';
import 'package:sure_mobile/providers/auth_provider.dart';
import 'package:sure_mobile/screens/country_selection_screen.dart';

class _SignedInAuthProvider extends AuthProvider {
  _SignedInAuthProvider(this._signedInUser);

  final User _signedInUser;

  @override
  User? get user => _signedInUser;

  @override
  bool get isInitializing => false;

  @override
  bool get isAuthenticated => true;

  @override
  bool get countryConfirmationRequired => true;
}

void main() {
  testWidgets('a signed-in member who still has to accept their country terms lands on the country screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    // The deep-link plugin has no platform side in tests.
    for (final channel in ['com.llfbandit.app_links/messages', 'com.llfbandit.app_links/events']) {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }

    final authProvider = _SignedInAuthProvider(User.fromJson({
      'id': 'user-1',
      'email': 'student@example.com',
      'ui_layout': 'intro',
      'ai_enabled': true,
      'country_code': 'RW',
      'requires_country_confirmation': false,
    }));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider(create: (_) => AppConfigProvider()),
        ],
        child: const MaterialApp(home: AppWrapper()),
      ),
    );
    // Startup reads preferences and the country list off the fake clock.
    for (var i = 0; i < 10 && find.text('Rwanda').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }

    expect(find.byType(CountrySelectionScreen), findsOneWidget);
    expect(find.text('Rwanda'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });
}
