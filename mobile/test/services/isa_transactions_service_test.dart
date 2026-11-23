import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sure_mobile/services/isa_transactions_service.dart';
import 'package:sure_mobile/services/my_account_service.dart'
    show EmailVerificationRequiredException;

void main() {
  group('IsaTransactionsService', () {
    IsaTransactionsService serviceReturning(http.Response Function() respond) {
      return IsaTransactionsService(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/my_account_transactions');
          expect(request.headers['Authorization'], 'Bearer token');
          return respond();
        }),
      );
    }

    test('parses a 200 list of transactions', () async {
      final service = serviceReturning(() => http.Response(
            '[{"payment_type":"Repayment","amount":1250.5,'
            '"currency":"KES","payment_date":"2026-09-01"}]',
            200,
          ));

      final result = await service.fetchTransactions('token');

      expect(result, hasLength(1));
      expect(result.first.paymentType, 'Repayment');
      expect(result.first.amount, 1250.5);
    });

    test('returns an empty list for a genuine empty 200', () async {
      final service = serviceReturning(() => http.Response('[]', 200));

      expect(await service.fetchTransactions('token'), isEmpty);
    });

    test('maps 503 to IsaTransactionsUnavailableException', () async {
      final service = serviceReturning(
          () => http.Response('{"error":"service_unavailable"}', 503));

      expect(
        () => service.fetchTransactions('token'),
        throwsA(isA<IsaTransactionsUnavailableException>()),
      );
    });

    test('maps 502 to IsaTransactionsUpstreamException with status code', () async {
      final service = serviceReturning(
          () => http.Response('{"error":"upstream_error"}', 502));

      expect(
        () => service.fetchTransactions('token'),
        throwsA(isA<IsaTransactionsUpstreamException>()
            .having((e) => e.statusCode, 'statusCode', 502)),
      );
    });

    test('maps other non-200 (500) to IsaTransactionsUpstreamException', () async {
      final service = serviceReturning(() => http.Response('boom', 500));

      expect(
        () => service.fetchTransactions('token'),
        throwsA(isA<IsaTransactionsUpstreamException>()),
      );
    });

    test('maps 403 email_verification_required to EmailVerificationRequiredException',
        () async {
      final service = serviceReturning(() => http.Response(
            '{"error":"email_verification_required"}',
            403,
          ));

      expect(
        () => service.fetchTransactions('token'),
        throwsA(isA<EmailVerificationRequiredException>()),
      );
    });

    test('maps a SocketException to IsaTransactionsNetworkException', () async {
      final service = IsaTransactionsService(
        client: MockClient((_) async => throw const SocketException('offline')),
      );

      expect(
        () => service.fetchTransactions('token'),
        throwsA(isA<IsaTransactionsNetworkException>()),
      );
    });

    test('maps a TimeoutException to IsaTransactionsNetworkException', () async {
      final service = IsaTransactionsService(
        client: MockClient((_) async => throw TimeoutException('slow')),
      );

      expect(
        () => service.fetchTransactions('token'),
        throwsA(isA<IsaTransactionsNetworkException>()),
      );
    });
  });
}
