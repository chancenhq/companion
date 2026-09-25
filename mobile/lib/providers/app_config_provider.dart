import 'package:flutter/foundation.dart';
import '../services/app_config_service.dart';
import '../services/preferences_service.dart';

class AppConfigProvider extends ChangeNotifier {
  static const _fallbackUrl =
      'https://chat.whatsapp.com/IVBXS2QtJpqIFlZYoSPD1t';

  static const _countryNameToCode = {
    'Kenya': 'ke',
    'Rwanda': 'rw',
    'South Africa': 'za',
    'Ghana': 'gh',
  };

  Map<String, String> _whatsappUrls = {};

  String whatsappUrlForCountry(String countryName) {
    final code = _countryNameToCode[countryName];
    return (code != null ? _whatsappUrls[code] : null) ?? _fallbackUrl;
  }

  Future<void> load() async {
    // Phase 1: serve from cache immediately — no network required.
    final cached = await PreferencesService.instance.getWhatsappUrls();
    if (cached.isNotEmpty && _whatsappUrls != cached) {
      _whatsappUrls = cached;
      notifyListeners();
    }

    // Phase 2: refresh from API in background; persist + notify only if changed.
    final config = await AppConfigService().fetchConfig();
    final raw = config?['whatsapp_group_urls'];
    if (raw is! Map) return;

    final fresh = Map<String, String>.from(
      raw.map((k, v) => MapEntry(k.toString(), v.toString())),
    );
    if (fresh.isNotEmpty && fresh != _whatsappUrls) {
      _whatsappUrls = fresh;
      await PreferencesService.instance.setWhatsappUrls(fresh);
      notifyListeners();
    }
  }
}
