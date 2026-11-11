import 'package:flutter/foundation.dart';

import '../services/app_config_service.dart';
import '../services/preferences_service.dart';

class AppConfigProvider extends ChangeNotifier {
  AppConfigProvider({AppConfigService? service})
      : _service = service ?? AppConfigService();

  static const _fallbackUrls = {
    'ke': 'https://chat.whatsapp.com/IVBXS2QtJpqIFlZYoSPD1t',
  };

  final AppConfigService _service;
  Map<String, String> _whatsappUrls = {};

  Uri? whatsappUriForCode(String? countryCode) {
    final code = countryCode?.trim().toLowerCase();
    if (code == null || code.isEmpty) return null;

    final value = _whatsappUrls[code] ?? _fallbackUrls[code];
    if (value == null) return null;

    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.toLowerCase() != 'chat.whatsapp.com') {
      return null;
    }
    return uri;
  }

  Future<void> load() async {
    final cached = await PreferencesService.instance.getWhatsappUrls();
    if (!mapEquals(cached, _whatsappUrls)) {
      _whatsappUrls = cached;
      notifyListeners();
    }

    final config = await _service.fetchConfig();
    if (config == null || !config.containsKey('whatsapp_group_urls')) return;

    final raw = config['whatsapp_group_urls'];
    if (raw is! Map) return;

    final fresh = <String, String>{};
    for (final entry in raw.entries) {
      if (entry.value is String) {
        fresh[entry.key.toString().toLowerCase()] = entry.value as String;
      }
    }

    if (!mapEquals(fresh, _whatsappUrls)) {
      _whatsappUrls = fresh;
      await PreferencesService.instance.setWhatsappUrls(fresh);
      notifyListeners();
    }
  }
}
