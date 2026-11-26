import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/isa_transaction.dart';
import 'api_config.dart';
import 'auth_events.dart';
import 'my_account_service.dart' show EmailVerificationRequiredException;

/// The transaction data service isn't configured (backend returns 503).
class IsaTransactionsUnavailableException implements Exception {
  const IsaTransactionsUnavailableException();
}

/// The device has no network or the request timed out.
class IsaTransactionsNetworkException implements Exception {
  const IsaTransactionsNetworkException();
}

/// The server returned an unexpected error (e.g. 502 from Metabase).
class IsaTransactionsUpstreamException implements Exception {
  final int statusCode;
  const IsaTransactionsUpstreamException(this.statusCode);
}

class IsaTransactionsService {
  IsaTransactionsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<IsaTransaction>> fetchTransactions(String accessToken) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/my_account_transactions');
      final response = await _client.get(
        url,
        headers: ApiConfig.getAuthHeaders(accessToken),
      ).timeout(const Duration(seconds: 20));

      AuthEvents.instance.report(response);
      if (AuthEvents.isEmailVerificationRequired(response)) {
        throw const EmailVerificationRequiredException();
      }
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list
            .map((e) => IsaTransaction.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (response.statusCode == 503) throw const IsaTransactionsUnavailableException();
      throw IsaTransactionsUpstreamException(response.statusCode);
    } on EmailVerificationRequiredException {
      rethrow;
    } on IsaTransactionsUnavailableException {
      rethrow;
    } on IsaTransactionsUpstreamException {
      rethrow;
    } on SocketException {
      throw const IsaTransactionsNetworkException();
    } on TimeoutException {
      throw const IsaTransactionsNetworkException();
    } catch (_) {
      throw const IsaTransactionsNetworkException();
    }
  }
}
