import 'package:flutter_test/flutter_test.dart';
import 'package:sure_mobile/models/isa_transaction.dart';

void main() {
  group('IsaTransaction', () {
    test('parses a full payload', () {
      final txn = IsaTransaction.fromJson({
        'payment_type': 'Repayment',
        'amount': 1250.5,
        'currency': 'KES',
        'payment_date': '2026-09-01',
      });

      expect(txn.paymentType, 'Repayment');
      expect(txn.amount, 1250.5);
      expect(txn.currency, 'KES');
      expect(txn.paymentDate, '2026-09-01');
    });

    test('coerces integer amount to double', () {
      final txn = IsaTransaction.fromJson({'amount': 100});

      expect(txn.amount, 100.0);
      expect(txn.amount, isA<double>());
    });

    test('defaults missing/null fields', () {
      final txn = IsaTransaction.fromJson({});

      expect(txn.paymentType, '');
      expect(txn.amount, 0.0);
      expect(txn.currency, '');
      expect(txn.paymentDate, '');
    });
  });
}
