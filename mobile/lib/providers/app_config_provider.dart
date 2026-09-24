import 'package:flutter/foundation.dart';
import '../services/app_config_service.dart';

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
    final config = await AppConfigService().fetchConfig();
    final urls = config?['whatsapp_group_urls'];
    if (urls is Map) {
      _whatsappUrls = Map<String, String>.from(
        urls.map((k, v) => MapEntry(k.toString(), v.toString())),
      );
      notifyListeners();
    }
  }
}
