import 'package:flutter_test/flutter_test.dart';
import 'package:sure_mobile/models/chancen_country.dart';

void main() {
  test('parses country API payloads', () {
    final country = ChancenCountry.fromJson({
      'code': 'rw',
      'name': 'Rwanda',
      'live': true,
      'privacy_url': '/privacy/rw',
      'terms_url': '/terms/rw',
    });

    expect(country.code, 'RW');
    expect(country.name, 'Rwanda');
    expect(country.live, isTrue);
  });

  test('resolves relative legal URLs against the configured backend', () {
    const country = ChancenCountry(
      code: 'KE',
      name: 'Kenya',
      live: true,
      privacyUrl: '/privacy/ke',
      termsUrl: '/terms/ke',
    );

    expect(
      country.privacyUri('https://companion.example.com/api').toString(),
      'https://companion.example.com/privacy/ke',
    );
    expect(
      country.termsUri('https://companion.example.com/api').toString(),
      'https://companion.example.com/terms/ke',
    );
  });
}
