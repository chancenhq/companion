import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import '../models/student_account.dart';

class MyAccountService {
  Future<Map<String, dynamic>> fetchMyAccount({
    required String accessToken,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/my_account');

      final response = await http.get(
        url,
        headers: ApiConfig.getAuthHeaders(accessToken),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, 'account': StudentAccount.fromJson(data)};
      } else if (response.statusCode == 401) {
        return {'success': false, 'error': 'Session expired. Please login again.'};
      } else if (response.statusCode == 404) {
        return {'success': false, 'not_found': true};
      } else if (response.statusCode == 503) {
        return {'success': false, 'not_configured': true};
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': false, 'error': data['error'] ?? 'Failed to load account data'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }
}
