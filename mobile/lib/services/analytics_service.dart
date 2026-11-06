import 'package:posthog_flutter/posthog_flutter.dart';

import '../models/user.dart';

class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._();

  AnalyticsService._();

  bool _enabled = false;
  User? _pendingUser;

  Future<void> init({required String host, required String apiKey}) async {
    if (_enabled) return;

    final config = PostHogConfig(apiKey)..host = host;
    await Posthog().setup(config);
    _enabled = true;

    final pendingUser = _pendingUser;
    if (pendingUser != null) {
      _pendingUser = null;
      identify(pendingUser);
    }
  }

  void identify(User user) {
    if (!_enabled) {
      _pendingUser = user;
      return;
    }

    final properties = <String, Object>{
      'has_password': user.hasPassword ?? false,
      'ai_enabled': user.aiEnabled,
      'ui_layout': user.uiLayout,
    };
    if (user.countryCode != null) {
      properties['country_code'] = user.countryCode!;
    }

    Posthog().identify(userId: user.id, userProperties: properties);
  }

  void capture(
    String event, [
    Map<String, Object> properties = const {},
  ]) {
    if (!_enabled) return;
    Posthog().capture(eventName: event, properties: properties);
  }

  void screen(String screenName) {
    if (!_enabled) return;
    Posthog().screen(screenName: screenName);
  }

  void reset() {
    _pendingUser = null;
    if (!_enabled) return;
    Posthog().reset();
  }
}
