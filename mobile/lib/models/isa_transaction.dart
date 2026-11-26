// Mirrors the warehouse `transaction_tag`, which classifies every payment by
// its effect on the user's financed principal:
//   chancenFunding    -> "increase principal" (paid by Chancen FOR the user)
//   balanceReduction  -> "reduce principal"   (paid BY the user; a repayment)
//   noPrincipalEffect -> "do not affect principal" (fees, penalties, deposits)
// `other` is a safety fallback for a payment type we haven't mapped yet; an
// unknown type must not be assumed to reduce (or not reduce) the balance.
enum IsaPaymentCategory {
  chancenFunding,
  balanceReduction,
  noPrincipalEffect,
  other,
}

class IsaTransaction {
  const IsaTransaction({
    required this.paymentType,
    required this.amount,
    required this.currency,
    required this.paymentDate,
  });

  final String paymentType;
  final double amount;
  final String currency;
  final String paymentDate;

  String get normalizedPaymentType => paymentType
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  IsaPaymentCategory get category =>
      _paymentCategories[normalizedPaymentType] ?? IsaPaymentCategory.other;

  static const _paymentCategories = <String, IsaPaymentCategory>{
    'cobooth monthly flat payment': IsaPaymentCategory.balanceReduction,
    'cobooth payment': IsaPaymentCategory.balanceReduction,
    'commitment fee': IsaPaymentCategory.balanceReduction,
    'commitment fees': IsaPaymentCategory.balanceReduction,
    'commitment payment': IsaPaymentCategory.balanceReduction,
    'contribution fee': IsaPaymentCategory.balanceReduction,
    'drop out fee': IsaPaymentCategory.balanceReduction,
    'repayment': IsaPaymentCategory.balanceReduction,
    'write off collection payment': IsaPaymentCategory.balanceReduction,
    'pei payment': IsaPaymentCategory.chancenFunding,
    'admin fee': IsaPaymentCategory.noPrincipalEffect,
    'application fee': IsaPaymentCategory.noPrincipalEffect,
    'application fees': IsaPaymentCategory.noPrincipalEffect,
    'deposit': IsaPaymentCategory.noPrincipalEffect,
    'dropout penalty': IsaPaymentCategory.noPrincipalEffect,
    'drop out penalty': IsaPaymentCategory.noPrincipalEffect,
    'penalty fee': IsaPaymentCategory.noPrincipalEffect,
  };

  factory IsaTransaction.fromJson(Map<String, dynamic> json) {
    return IsaTransaction(
      paymentType: (json['payment_type'] as String?) ?? '',
      amount:      (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency:    (json['currency'] as String?) ?? '',
      paymentDate: (json['payment_date'] as String?) ?? '',
    );
  }
}
