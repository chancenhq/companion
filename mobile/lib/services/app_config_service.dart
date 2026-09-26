import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'log_service.dart';

class AppConfigService {
  Future<Map<String, dynamic>?> fetchConfig() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/app_config');
      final response = await http
          .get(url, headers: ApiConfig.jsonHeaders())
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      LogService.instance.debug('AppConfigService', 'Config fetch failed: $e');
    }
    return null;
  }
}
