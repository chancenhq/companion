import 'package:flutter_test/flutter_test.dart';
import 'package:sure_mobile/models/user.dart';

void main() {
  test('parses country and verification fields from snake case payloads', () {
    final user = User.fromJson({
      'id': 123,
      'email': 'student@example.com',
      'first_name': 'Student',
      'last_name': 'One',
      'ui_layout': 'intro',
      'ai_enabled': true,
      'country_code': 'rw',
      'email_verified': false,
      'requires_country_confirmation': true,
    });

    expect(user.countryCode, 'RW');
    expect(user.emailVerified, isFalse);
    expect(user.requiresCountryConfirmation, isTrue);
    expect(user.isIntroLayout, isTrue);
  });

  test('keeps older cached users usable with safe defaults', () {
    final user = User.fromJson({
      'id': 'abc',
      'email': 'student@example.com',
    });

    expect(user.uiLayout, 'dashboard');
    expect(user.aiEnabled, isFalse);
    expect(user.countryCode, isNull);
    expect(user.emailVerified, isTrue);
    expect(user.requiresCountryConfirmation, isFalse);
  });

  test('serializes verification and country fields', () {
    final json = User(
      id: 'abc',
      email: 'student@example.com',
      uiLayout: 'dashboard',
      aiEnabled: false,
      countryCode: 'GH',
      emailVerified: false,
      requiresCountryConfirmation: true,
    ).toJson();

    expect(json['country_code'], 'GH');
    expect(json['email_verified'], isFalse);
    expect(json['requires_country_confirmation'], isTrue);
  });
}
