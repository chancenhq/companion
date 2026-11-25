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

    test('classifies the known balance-reducing payment types', () {
      for (final type in [
        'CoBooth Monthly Flat Payment',
        'CoBooth Payment',
        'Commitment Fee',
        'Commitment Fees',
        'Commitment Payment',
        'Contribution Fee',
        'Drop-out Fee',
        'Repayment',
        'Write-Off Collection Payment',
      ]) {
        final txn = IsaTransaction.fromJson({'payment_type': type});

        expect(txn.category, IsaPaymentCategory.balanceReduction);
      }
    });

    test('classifies PEI payments as Chancen funding', () {
      final txn = IsaTransaction.fromJson({'payment_type': 'PEI Payment'});

      expect(txn.category, IsaPaymentCategory.chancenFunding);
    });

    test('groups fees, deposits and penalties as not affecting principal', () {
      for (final type in [
        'Admin fee',
        'Application Fees',
        'Deposit',
        'Dropout Penalty',
        'Penalty fee',
      ]) {
        final txn = IsaTransaction.fromJson({'payment_type': type});

        expect(txn.category, IsaPaymentCategory.noPrincipalEffect);
      }
    });

    test('keeps unknown payment types visible as other', () {
      final txn = IsaTransaction.fromJson({'payment_type': 'Adjustment'});

      expect(txn.category, IsaPaymentCategory.other);
    });
  });
}
