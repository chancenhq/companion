import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/isa_transaction.dart';
import 'api_config.dart';

class IsaTransactionsUnavailableException implements Exception {
  const IsaTransactionsUnavailableException();
}

class IsaTransactionsService {
  Future<List<IsaTransaction>> fetchTransactions(String accessToken) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/my_account_transactions');
      final response = await http.get(
        url,
        headers: ApiConfig.getAuthHeaders(accessToken),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list
            .map((e) => IsaTransaction.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (response.statusCode == 503) throw const IsaTransactionsUnavailableException();
      return [];
    } catch (e) {
      if (e is IsaTransactionsUnavailableException) rethrow;
      return [];
    }
  }
}
