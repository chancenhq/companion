import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:sure_mobile/providers/auth_provider.dart';
import 'package:sure_mobile/screens/login_screen.dart';
import 'package:sure_mobile/services/api_config.dart';

void main() {
  group('login screen goldens', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      ApiConfig.clearApiKeyAuth();
    });

    tearDown(() {
      ApiConfig.clearApiKeyAuth();
    });

    goldenTest(
      'renders the core returning-member login screen',
      fileName: 'login_screen_default',
      constraints: const BoxConstraints.tightFor(width: 390, height: 844),
      builder: () => _loginScreenWith(_GoldenAuthProvider()),
    );

    goldenTest(
      'renders the wrong-password error state',
      fileName: 'login_screen_wrong_password_error',
      constraints: const BoxConstraints.tightFor(width: 390, height: 844),
      builder: () => _loginScreenWith(
        _GoldenAuthProvider(
          errorMessage: 'Invalid email or password',
        ),
      ),
    );

    goldenTest(
      'renders debug API-key login dialog',
      fileName: 'login_screen_api_key_dialog',
      constraints: const BoxConstraints.tightFor(width: 390, height: 844),
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        await tester.tap(find.text('API-Key Login'));
        await tester.pumpAndSettle();
      },
      builder: () => _loginScreenWith(_GoldenAuthProvider()),
    );
  });
}

Widget _loginScreenWith(AuthProvider authProvider) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: authProvider,
    child: const MaterialApp(home: LoginScreen()),
  );
}

class _GoldenAuthProvider extends AuthProvider {
  _GoldenAuthProvider({String? errorMessage}) : _errorMessage = errorMessage;

  final String? _errorMessage;

  @override
  bool get isLoading => false;

  @override
  bool get isInitializing => false;

  @override
  String? get errorMessage => _errorMessage;
}
