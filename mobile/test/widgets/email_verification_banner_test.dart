import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sure_mobile/models/user.dart';
import 'package:sure_mobile/providers/auth_provider.dart';
import 'package:sure_mobile/widgets/email_verification_banner.dart';

class _UnverifiedAuthProvider extends AuthProvider {
  bool resendCalled = false;
  bool dismissCalled = false;
  bool refreshCalled = false;

  @override
  User? get user => User.fromJson({
        'id': 'user-1',
        'email': 'student@example.com',
        'ui_layout': 'intro',
        'ai_enabled': true,
        'email_verified': false,
      });

  @override
  bool get showEmailVerificationPrompt => true;

  @override
  Future<String> resendEmailVerification() async {
    resendCalled = true;
    return 'Verification email sent.';
  }

  @override
  Future<bool> refreshUser() async {
    refreshCalled = true;
    return false;
  }

  @override
  void dismissEmailVerificationPrompt() {
    dismissCalled = true;
  }
}

void main() {
  Future<void> pumpBanner(WidgetTester tester, _UnverifiedAuthProvider provider) {
    return tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(body: EmailVerificationBanner()),
        ),
      ),
    );
  }

  testWidgets('shows the verification nudge with the email address', (tester) async {
    await pumpBanner(tester, _UnverifiedAuthProvider());

    expect(find.textContaining('Verify your email'), findsOneWidget);
    expect(find.textContaining('student@example.com'), findsOneWidget);
    expect(find.text("I've verified"), findsOneWidget);
    expect(find.text('Resend'), findsOneWidget);
  });

  testWidgets('Resend calls resendEmailVerification', (tester) async {
    final provider = _UnverifiedAuthProvider();
    await pumpBanner(tester, provider);

    await tester.tap(find.text('Resend'));
    await tester.pump();

    expect(provider.resendCalled, isTrue);
  });

  testWidgets("I've verified calls refreshUser", (tester) async {
    final provider = _UnverifiedAuthProvider();
    await pumpBanner(tester, provider);

    await tester.tap(find.text("I've verified"));
    await tester.pump();

    expect(provider.refreshCalled, isTrue);
  });

  testWidgets('dismiss calls dismissEmailVerificationPrompt', (tester) async {
    final provider = _UnverifiedAuthProvider();
    await pumpBanner(tester, provider);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(provider.dismissCalled, isTrue);
  });
}
