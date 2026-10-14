import 'package:posthog_flutter/posthog_flutter.dart';
import '../models/user.dart';

class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._();
  AnalyticsService._();

  bool _enabled = false;

  Future<void> init({required String host, required String apiKey}) async {
    if (_enabled) return;
    final config = PostHogConfig(apiKey)..host = host;
    await Posthog().setup(config);
    _enabled = true;
  }

  void identify(User user) {
    if (!_enabled) return;
    final props = <String, Object>{
      'has_password': user.hasPassword ?? false,
      'ai_enabled': user.aiEnabled,
      'ui_layout': user.uiLayout,
    };
    if (user.countryCode != null) props['country_code'] = user.countryCode!;

    Posthog().identify(userId: user.id, userProperties: props);
  }

  void capture(String event, [Map<String, Object> properties = const {}]) {
    if (!_enabled) return;
    Posthog().capture(eventName: event, properties: properties);
  }

  void reset() {
    if (!_enabled) return;
    Posthog().reset();
  }
}
