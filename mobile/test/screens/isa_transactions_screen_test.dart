import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sure_mobile/l10n/app_localizations.dart';
import 'package:sure_mobile/models/isa_transaction.dart';
import 'package:sure_mobile/screens/isa_transactions_screen.dart';
import 'package:sure_mobile/theme/sure_theme.dart';

void main() {
  Widget subject(List<IsaTransaction> transactions) {
    return MaterialApp(
      theme: SureTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PaymentsList(transactions: transactions),
      ),
    );
  }

  testWidgets('separates payments into the user-facing principal groups',
      (tester) async {
    await tester.pumpWidget(subject(const [
      IsaTransaction(
        paymentType: 'repayment',
        amount: 2500,
        currency: 'KES',
        paymentDate: '2026-10-03',
      ),
      IsaTransaction(
        paymentType: 'Commitment Fee',
        amount: 500,
        currency: 'KES',
        paymentDate: '2026-10-02',
      ),
      IsaTransaction(
        paymentType: 'PEI Payment',
        amount: 120000,
        currency: 'KES',
        paymentDate: '2026-09-01',
      ),
      IsaTransaction(
        paymentType: 'Application Fees',
        amount: 50,
        currency: 'KES',
        paymentDate: '2026-08-01',
      ),
      IsaTransaction(
        paymentType: 'Dropout Penalty',
        amount: 100,
        currency: 'KES',
        paymentDate: '2026-07-01',
      ),
    ]));

    expect(find.text('PAID BY CHANCEN'), findsOneWidget);
    expect(find.text('REDUCES YOUR BALANCE'), findsOneWidget);
    expect(find.text('DOES NOT REDUCE YOUR BALANCE'), findsOneWidget);
    expect(find.text('Repayment'), findsOneWidget);
    expect(find.text('Commitment payment'), findsOneWidget);
    expect(find.text('Chancen Financed'), findsOneWidget);
    expect(find.text('Application fee'), findsOneWidget);
    expect(find.text('Dropout penalty'), findsOneWidget);
  });

  testWidgets('opens payment details when a payment is tapped', (tester) async {
    await tester.pumpWidget(subject(const [
      IsaTransaction(
        paymentType: 'repayment',
        amount: 2500,
        currency: 'KES',
        paymentDate: '2026-10-03',
      ),
    ]));

    await tester.tap(find.text('Repayment'));
    await tester.pumpAndSettle();

    expect(find.text('Payment details'), findsOneWidget);
    expect(find.text('This payment reduces your financed balance.'),
        findsOneWidget);
    expect(find.text('Payment type'), findsOneWidget);
    expect(find.text('Repayment'), findsNWidgets(2));
  });

  testWidgets('opens the payment grouping explainer from the info button',
      (tester) async {
    await tester.pumpWidget(subject(const [
      IsaTransaction(
        paymentType: 'Repayment',
        amount: 2500,
        currency: 'KES',
        paymentDate: '2026-10-03',
      ),
    ]));

    expect(find.text('How payments are grouped'), findsNothing);

    await tester.tap(find.byTooltip('How payment groups work'));
    await tester.pumpAndSettle();

    expect(find.text('How payments are grouped'), findsOneWidget);
    expect(
      find.textContaining('Payments are grouped by how they affect'),
      findsOneWidget,
    );
  });
}
