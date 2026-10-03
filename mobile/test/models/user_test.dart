import 'package:flutter_test/flutter_test.dart';
import 'package:sure_mobile/models/user.dart';

void main() {
  Map<String, dynamic> payload([Map<String, dynamic> extra = const {}]) => {
        'id': 'user-1',
        'email': 'student@example.com',
        'ui_layout': 'intro',
        'ai_enabled': true,
        ...extra,
      };

  group('User.emailVerified', () {
    test('reads the server value', () {
      expect(User.fromJson(payload({'email_verified': true})).emailVerified, isTrue);
      expect(User.fromJson(payload({'email_verified': false})).emailVerified, isFalse);
    });

    test('is null (unknown, never locking) when the server does not say', () {
      expect(User.fromJson(payload()).emailVerified, isNull);
    });

    test('country fields: unknown never prompts, server values are kept', () {
      final unknown = User.fromJson(payload());
      expect(unknown.requiresCountryConfirmation, isNull);
      expect(unknown.countryCode, isNull);

      final user = User.fromJson(payload({
        'country_code': 'RW',
        'requires_country_confirmation': false,
        'consent_version': '1.0',
        'consent_country_code': 'RW',
      }));
      expect(user.countryCode, 'RW');
      expect(user.requiresCountryConfirmation, isFalse);
      expect(User.fromJson(user.toJson()).consentVersion, '1.0');
    });

    test('survives being stored and read back', () {
      final stored = User.fromJson(payload({'email_verified': false})).toJson();
      expect(User.fromJson(stored).emailVerified, isFalse);
    });
  });
}
