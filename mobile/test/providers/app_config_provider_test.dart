import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sure_mobile/providers/app_config_provider.dart';
import 'package:sure_mobile/services/app_config_service.dart';
import 'package:sure_mobile/services/preferences_service.dart';

class FakeAppConfigService extends AppConfigService {
  FakeAppConfigService(this.response);

  Map<String, dynamic>? response;

  @override
  Future<Map<String, dynamic>?> fetchConfig() async => response;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.resetForTest();
  });

  test('resolves configured links using the server country code', () async {
    final provider = AppConfigProvider(
      service: FakeAppConfigService({
        'whatsapp_group_urls': {
          'rw': 'https://chat.whatsapp.com/rwanda',
          'za': 'https://chat.whatsapp.com/south-africa',
        },
      }),
    );

    await provider.load();

    expect(
      provider.whatsappUriForCode('RW').toString(),
      'https://chat.whatsapp.com/rwanda',
    );
    expect(
      provider.whatsappUriForCode('za').toString(),
      'https://chat.whatsapp.com/south-africa',
    );
  });

  test('uses cached links when the server is unavailable', () async {
    SharedPreferences.setMockInitialValues({
      'app_config_whatsapp_urls': jsonEncode({
        'gh': 'https://chat.whatsapp.com/ghana',
      }),
    });
    PreferencesService.resetForTest();
    final provider = AppConfigProvider(service: FakeAppConfigService(null));

    await provider.load();

    expect(
      provider.whatsappUriForCode('GH').toString(),
      'https://chat.whatsapp.com/ghana',
    );
  });

  test('a successful empty response clears removed cached links', () async {
    SharedPreferences.setMockInitialValues({
      'app_config_whatsapp_urls': jsonEncode({
        'rw': 'https://chat.whatsapp.com/removed',
      }),
    });
    PreferencesService.resetForTest();
    final provider = AppConfigProvider(
      service: FakeAppConfigService({'whatsapp_group_urls': {}}),
    );

    await provider.load();

    expect(provider.whatsappUriForCode('RW'), isNull);
    expect(await PreferencesService.instance.getWhatsappUrls(), isEmpty);
  });

  test('never falls back to the Kenya link for another country', () {
    final provider = AppConfigProvider(service: FakeAppConfigService(null));

    expect(provider.whatsappUriForCode('RW'), isNull);
    expect(provider.whatsappUriForCode(null), isNull);
    expect(
      provider.whatsappUriForCode('KE').toString(),
      'https://chat.whatsapp.com/IVBXS2QtJpqIFlZYoSPD1t',
    );
  });

  test('rejects malformed or non-HTTPS cached links', () async {
    SharedPreferences.setMockInitialValues({
      'app_config_whatsapp_urls': jsonEncode({
        'rw': 'javascript:alert(1)',
        'za': 'https://example.com/not-whatsapp',
      }),
    });
    PreferencesService.resetForTest();
    final provider = AppConfigProvider(service: FakeAppConfigService(null));

    await provider.load();

    expect(provider.whatsappUriForCode('RW'), isNull);
    expect(provider.whatsappUriForCode('ZA'), isNull);
  });
}
