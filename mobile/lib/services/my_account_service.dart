import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/student_account.dart';
import 'api_config.dart';

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
      // 404 = no ISA record for this user (application stage / not yet in system)
      // 503 = Metabase not configured on server
      return null;
    } catch (_) {
      return null;
    }
  }
}
