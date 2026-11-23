import 'package:flutter_test/flutter_test.dart';
import 'package:sure_mobile/models/isa_transaction.dart';
import 'package:sure_mobile/providers/isa_transactions_provider.dart';
import 'package:sure_mobile/services/isa_transactions_service.dart';
import 'package:sure_mobile/services/my_account_service.dart'
    show EmailVerificationRequiredException;

/// Service stub whose [fetchTransactions] runs a swappable handler, so tests
/// drive the provider through success and each failure mode.
class _FakeService extends IsaTransactionsService {
  Future<List<IsaTransaction>> Function() handler = () async => [];

  @override
  Future<List<IsaTransaction>> fetchTransactions(String accessToken) => handler();
}

void main() {
  group('IsaTransactionsProvider', () {
    late _FakeService service;
    late IsaTransactionsProvider provider;

    setUp(() {
      service = _FakeService();
      provider = IsaTransactionsProvider(service: service);
    });

    final sample = IsaTransaction.fromJson({
      'payment_type': 'Repayment',
      'amount': 100,
      'currency': 'KES',
      'payment_date': '2026-09-01',
    });

    test('a successful load populates transactions and lastSyncedAt', () async {
      service.handler = () async => [sample];

      await provider.load('token');

      expect(provider.transactions, hasLength(1));
      expect(provider.loaded, isTrue);
      expect(provider.lastSyncedAt, isNotNull);
      expect(provider.networkError, isFalse);
      expect(provider.upstreamError, isFalse);
      expect(provider.unavailable, isFalse);
      expect(provider.verificationRequired, isFalse);
    });

    test('a network exception sets only networkError', () async {
      service.handler = () async => throw const IsaTransactionsNetworkException();

      await provider.load('token');

      expect(provider.networkError, isTrue);
      expect(provider.upstreamError, isFalse);
      expect(provider.loaded, isTrue);
    });

    test('an upstream exception sets only upstreamError', () async {
      service.handler = () async => throw const IsaTransactionsUpstreamException(502);

      await provider.load('token');

      expect(provider.upstreamError, isTrue);
      expect(provider.networkError, isFalse);
    });

    test('an unavailable exception sets only unavailable', () async {
      service.handler = () async => throw const IsaTransactionsUnavailableException();

      await provider.load('token');

      expect(provider.unavailable, isTrue);
      expect(provider.upstreamError, isFalse);
    });

    test('an email-verification exception sets verificationRequired', () async {
      service.handler = () async => throw const EmailVerificationRequiredException();

      await provider.load('token');

      expect(provider.verificationRequired, isTrue);
    });

    test('a failed refresh keeps the last-good transactions and timestamp', () async {
      service.handler = () async => [sample];
      await provider.load('token');
      final syncedAt = provider.lastSyncedAt;

      service.handler = () async => throw const IsaTransactionsNetworkException();
      await provider.load('token');

      // Stale data stays on screen behind the error flag.
      expect(provider.transactions, hasLength(1));
      expect(provider.networkError, isTrue);
      expect(provider.lastSyncedAt, syncedAt);
    });
  });
}
