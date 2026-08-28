import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:sure_mobile/providers/auth_provider.dart';
import 'package:sure_mobile/screens/login_screen.dart';
import 'package:sure_mobile/services/api_config.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    ApiConfig.clearApiKeyAuth();
  });

  tearDown(() {
    ApiConfig.clearApiKeyAuth();
  });

  testWidgets('shows the API-key login dialog in debug test builds',
      (tester) async {
    final authProvider = AuthProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('API-Key Login'), findsOneWidget);

    await tester.ensureVisible(find.text('API-Key Login'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('API-Key Login'));
    await tester.pumpAndSettle();

    expect(find.text('API Key Login'), findsOneWidget);
    expect(find.text('Enter your API key to sign in.'), findsOneWidget);
    expect(find.byIcon(Icons.vpn_key_outlined), findsWidgets);
  });
}
