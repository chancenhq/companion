import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/student_account.dart';
import 'api_config.dart';

class AccountNotFoundException implements Exception {
  const AccountNotFoundException();
}

class AccountServiceUnavailableException implements Exception {
  const AccountServiceUnavailableException();
}

class MyAccountService {
  Future<StudentAccount?> fetchMyAccount(String accessToken) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/my_account');
      final response = await http.get(
        url,
        headers: ApiConfig.getAuthHeaders(accessToken),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return StudentAccount.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }
      if (response.statusCode == 404) throw const AccountNotFoundException();
      if (response.statusCode == 503) throw const AccountServiceUnavailableException();
      return null;
    } catch (e) {
      if (e is AccountNotFoundException) rethrow;
      if (e is AccountServiceUnavailableException) rethrow;
      return null;
    }
  }
}
