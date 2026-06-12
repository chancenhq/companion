class StudentAccount {
  final String email;
  final String status;
  final double totalFinanced;
  final double repaymentsReceived;
  final double maxAmount;
  final int installmentsPaid;
  final int maxInstallments;
  final String currency;

  const StudentAccount({
    required this.email,
    required this.status,
    required this.totalFinanced,
    required this.repaymentsReceived,
    required this.maxAmount,
    required this.installmentsPaid,
    required this.maxInstallments,
    required this.currency,
  });

  factory StudentAccount.fromJson(Map<String, dynamic> json) {
    return StudentAccount(
      email: json['email'] as String,
      status: json['status'] as String,
      totalFinanced: (json['total_financed'] as num).toDouble(),
      repaymentsReceived: (json['repayments_received'] as num).toDouble(),
      maxAmount: (json['max_amount'] as num).toDouble(),
      installmentsPaid: (json['installments_paid'] as num).toInt(),
      maxInstallments: (json['max_installments'] as num).toInt(),
      currency: json['currency'] as String? ?? 'KES',
    );
  }
}
