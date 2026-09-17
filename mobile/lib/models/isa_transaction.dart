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

  factory IsaTransaction.fromJson(Map<String, dynamic> json) {
    return IsaTransaction(
      paymentType: (json['payment_type'] as String?) ?? '',
      amount:      (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency:    (json['currency'] as String?) ?? '',
      paymentDate: (json['payment_date'] as String?) ?? '',
    );
  }
}
