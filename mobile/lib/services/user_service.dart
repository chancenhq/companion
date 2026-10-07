import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_events.dart';

class UserService {
  Future<Map<String, dynamic>> resetAccount({
    required String accessToken,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/users/reset');

      final response = await http.delete(
        url,
        headers: ApiConfig.getAuthHeaders(accessToken),
      ).timeout(const Duration(seconds: 30));
      AuthEvents.instance.report(response);

      if (response.statusCode == 200) {
        return {'success': true};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired. Please login again.',
        };
      } else {
        final responseData = jsonDecode(response.body);
        return {
          'success': false,
          'error': responseData['error'] ?? 'Failed to reset account',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> updatePassword({
    required String accessToken,
    String? currentPassword,
    required String newPassword,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/users/me/password');
      final body = <String, dynamic>{'user': {'password': newPassword}};
      if (currentPassword != null) body['user']['current_password'] = currentPassword;

      final response = await http.patch(
        url,
        headers: {...ApiConfig.getAuthHeaders(accessToken), 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));
      AuthEvents.instance.report(response);

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final responseData = jsonDecode(response.body);
        return {
          'success': false,
          'error': (responseData['errors'] as List?)?.join(', ') ?? responseData['message'] ?? 'Failed to update password',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> deleteAccount({
    required String accessToken,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/users/me');

      final response = await http.delete(
        url,
        headers: ApiConfig.getAuthHeaders(accessToken),
      ).timeout(const Duration(seconds: 30));
      AuthEvents.instance.report(response);

      if (response.statusCode == 200) {
        return {'success': true};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired. Please login again.',
        };
      } else {
        final responseData = jsonDecode(response.body);
        return {
          'success': false,
          'error': responseData['error'] ?? 'Failed to delete account',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }
}
