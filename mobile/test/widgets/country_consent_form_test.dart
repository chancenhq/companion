import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sure_mobile/models/chancen_country.dart';
import 'package:sure_mobile/widgets/country_consent_form.dart';

void main() {
  const countries = [
    ChancenCountry(code: 'KE', name: 'Kenya', live: true, privacyUrl: '/privacy/ke', termsUrl: '/terms/ke'),
    ChancenCountry(code: 'RW', name: 'Rwanda', live: true, privacyUrl: '/privacy/rw', termsUrl: '/terms/rw'),
  ];

  Future<List<String>> pumpForm(WidgetTester tester, {String? Function(String code)? result}) async {
    final submitted = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CountryConsentForm(
          loadCountries: () async => countries,
          onSubmit: (code) async {
            submitted.add(code);
            return result?.call(code);
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return submitted;
  }

  FilledButton continueButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'));

  testWidgets('nothing is pre-selected and Continue starts disabled', (tester) async {
    await pumpForm(tester);

    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(continueButton(tester).onPressed, isNull);
  });

  testWidgets('Continue needs both a country and consent', (tester) async {
    final submitted = await pumpForm(tester);

    await tester.tap(find.byKey(const ValueKey('country-RW')));
    await tester.pump();
    expect(continueButton(tester).onPressed, isNull, reason: 'no consent yet');

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(continueButton(tester).onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(submitted, ['RW']);
  });

  testWidgets('shows the error when saving fails', (tester) async {
    await pumpForm(tester, result: (_) => 'Network unavailable. Please try again.');

    await tester.tap(find.byKey(const ValueKey('country-KE')));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Network unavailable. Please try again.'), findsOneWidget);
  });
}
