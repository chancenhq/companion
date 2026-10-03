import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sure_mobile/providers/auth_provider.dart';
import 'package:sure_mobile/screens/login_screen.dart';

void main() {
  Future<void> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: AuthProvider(),
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LoginFormBody(branded: true, allowSignUp: true),
            ),
          ),
        ),
      ),
    );
    // Let AuthProvider's startup load (secure storage) finish outside the
    // fake-async zone, so the form isn't stuck in its loading state.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
  }

  testWidgets('offers Continue with email next to Google, with the Chancen email hint', (tester) async {
    await pumpForm(tester);

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);
    expect(find.text('Use the email address you gave Chancen.'), findsOneWidget);
    expect(find.text('Email'), findsNothing, reason: 'email form opens from the button');
  });

  testWidgets('email view has sign in, sign up, forgot password and upfront password rules', (tester) async {
    await pumpForm(tester);

    await tester.tap(find.byKey(const ValueKey('continue-with-email')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Other ways to sign in'), findsOneWidget);

    await tester.tap(find.text('Sign Up'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('At least 8 characters'), findsOneWidget);
    expect(find.text('Forgot password?'), findsNothing);
  });

  testWidgets('sign up checks the password rules before submitting', (tester) async {
    await pumpForm(tester);
    await tester.tap(find.byKey(const ValueKey('continue-with-email')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Sign Up'));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.widgetWithText(TextFormField, 'First name'), 'Amina');
    await tester.enterText(find.widgetWithText(TextFormField, 'Last name'), 'Otieno');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'amina@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password');
    final createAccount = find.widgetWithText(ElevatedButton, 'Create Account');
    await tester.ensureVisible(createAccount);
    await tester.pump();
    await tester.tap(createAccount);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Use both upper and lower case letters.'), findsOneWidget);
  });
}
