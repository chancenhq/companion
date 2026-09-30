import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sure_mobile/providers/auth_provider.dart';
import 'package:sure_mobile/services/api_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const connectivityChannel =
      MethodChannel('dev.fluttercommunity.plus/connectivity');

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    ApiConfig.clearApiKeyAuth();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel, null);
  });

  tearDown(() {
    ApiConfig.clearApiKeyAuth();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel, null);
  });

  group('stored auth startup', () {
    test('treats stored unexpired OAuth tokens as authenticated', () async {
      FlutterSecureStorage.setMockInitialValues({
        'auth_tokens': _tokensJson(
          accessToken: 'stored-access-token',
          refreshToken: 'stored-refresh-token',
          createdAt: _unixNow(),
          expiresIn: 3600,
        ),
        'user_data': _userJson(),
      });

      final provider = AuthProvider();
      await _waitForInitialization(provider);

      expect(provider.isInitializing, isFalse);
      expect(provider.isAuthenticated, isTrue);
      expect(provider.tokens?.accessToken, 'stored-access-token');
      expect(provider.user?.email, 'member@example.com');
    });

    test('logs out locally when stored OAuth tokens are expired and offline',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(connectivityChannel, (call) async {
        if (call.method == 'check') return ['none'];
        return null;
      });

      FlutterSecureStorage.setMockInitialValues({
        'auth_tokens': _tokensJson(
          accessToken: 'expired-access-token',
          refreshToken: 'expired-refresh-token',
          createdAt: _unixNow() - 7200,
          expiresIn: 3600,
        ),
        'user_data': _userJson(),
      });

      final provider = AuthProvider();
      await _waitForInitialization(provider);

      expect(provider.isInitializing, isFalse);
      expect(provider.isAuthenticated, isFalse);
      expect(provider.tokens, isNull);
      expect(provider.user, isNull);

      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'auth_tokens'), isNull);
      expect(await storage.read(key: 'user_data'), isNull);
    });

    test('restores persisted API-key auth without checking build mode',
        () async {
      FlutterSecureStorage.setMockInitialValues({
        'auth_mode': 'api_key',
        'api_key': 'stored-api-key',
      });

      final provider = AuthProvider();
      await _waitForInitialization(provider);

      expect(provider.isInitializing, isFalse);
      expect(provider.isApiKeyAuth, isTrue);
      expect(provider.isAuthenticated, isTrue);
      expect(await provider.getValidAccessToken(), 'stored-api-key');
      expect(ApiConfig.isApiKeyAuth, isTrue);
    });
  });
}

Future<void> _waitForInitialization(AuthProvider provider) async {
  for (var i = 0; i < 50; i += 1) {
    if (!provider.isInitializing) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  fail('AuthProvider did not finish initializing');
}

String _tokensJson({
  required String accessToken,
  required String refreshToken,
  required int createdAt,
  required int expiresIn,
}) {
  return jsonEncode({
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'token_type': 'Bearer',
    'expires_in': expiresIn,
    'created_at': createdAt,
  });
}

String _userJson() {
  return jsonEncode({
    'id': 'user-1',
    'email': 'member@example.com',
    'first_name': 'Member',
    'last_name': 'Example',
    'ui_layout': 'dashboard',
    'ai_enabled': false,
  });
}

int _unixNow() => DateTime.now().millisecondsSinceEpoch ~/ 1000;
