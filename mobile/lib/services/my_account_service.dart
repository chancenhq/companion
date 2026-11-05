import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/student_account.dart';
import 'api_config.dart';

class AccountNotFoundException implements Exception {
  const AccountNotFoundException();
}

class AccountServiceUnavailableException implements Exception {
  const AccountServiceUnavailableException();
}

class AccountNetworkException implements Exception {
  const AccountNetworkException();
}

class AccountUpstreamException implements Exception {
  final int statusCode;
  const AccountUpstreamException(this.statusCode);
}

/// Thrown when the API rejects a financial-data request because the user's
/// email is not yet verified. Shared by services that hit email-gated
/// endpoints (e.g. My Account, ISA transactions).
class EmailVerificationRequiredException implements Exception {
  const EmailVerificationRequiredException();
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
      throw AccountUpstreamException(response.statusCode);
    } on AccountNotFoundException {
      rethrow;
    } on AccountServiceUnavailableException {
      rethrow;
    } on AccountUpstreamException {
      rethrow;
    } on SocketException {
      throw const AccountNetworkException();
    } catch (_) {
      throw const AccountNetworkException();
    }
  }
}
