import 'package:flutter/foundation.dart';

import '../services/analytics_service.dart';
import '../services/app_config_service.dart';

class AppConfigProvider extends ChangeNotifier {
  Future<void> load() async {
    final config = await AppConfigService().fetchConfig();
    final posthog = config?['posthog'];
    if (posthog is! Map) return;

    final host = posthog['host'];
    final apiKey = posthog['api_key'];
    if (host is String &&
        host.isNotEmpty &&
        apiKey is String &&
        apiKey.isNotEmpty) {
      await AnalyticsService.instance.init(host: host, apiKey: apiKey);
    }
  }
}
