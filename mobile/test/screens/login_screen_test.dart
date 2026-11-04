import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sure_mobile/l10n/app_localizations.dart';
import 'package:sure_mobile/providers/auth_provider.dart';
import 'package:sure_mobile/screens/login_screen.dart';
import 'package:sure_mobile/theme/sure_theme.dart';

// The Chancen login uses LoginFormBody (branded): Google + Apple + "Continue
// with email", rather than companion-new's dynamic SSO-provider list.
void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<void> pumpLogin(WidgetTester tester) {
    return tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(),
        child: MaterialApp(
          theme: SureTheme.light,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const LoginScreen(),
        ),
      ),
    );
  }

  testWidgets('offers Google and email sign-in on the branded login',
      (tester) async {
    await pumpLogin(tester);
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byKey(const ValueKey('continue-with-email')), findsOneWidget);
  });

  testWidgets('opens the email form when "Continue with email" is tapped',
      (tester) async {
    await pumpLogin(tester);
    await tester.pumpAndSettle();

    // The email/password fields sit behind the choice screen until the member
    // opts into the email form.
    expect(find.widgetWithText(TextFormField, 'Email'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('continue-with-email')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
  });
}
