import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sure_mobile/models/chancen_country.dart';
import 'package:sure_mobile/widgets/country_consent_form.dart';

void main() {
  const countries = [
    ChancenCountry(code: 'KE', name: 'Kenya', live: true, privacyUrl: '/privacy/ke', termsUrl: '/terms/ke'),
    ChancenCountry(code: 'RW', name: 'Rwanda', live: true, privacyUrl: '/privacy/rw', termsUrl: '/terms/rw'),
  ];

  Future<List<String>> pumpForm(
    WidgetTester tester, {
    String? Function(String code)? result,
    String? lockedCountryCode,
  }) async {
    final submitted = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CountryConsentForm(
          loadCountries: () async => countries,
          lockedCountryCode: lockedCountryCode,
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

  testWidgets('a locked country is the only one shown and cannot be changed', (tester) async {
    final submitted = await pumpForm(tester, lockedCountryCode: 'RW');

    expect(find.text('Rwanda'), findsOneWidget);
    expect(find.text('Kenya'), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(continueButton(tester).onPressed, isNull, reason: 'consent is still required');

    await tester.tap(find.byKey(const ValueKey('country-RW')));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(submitted, ['RW']);
  });

  testWidgets('a locked country missing from the list can still be accepted', (tester) async {
    final submitted = await pumpForm(tester, lockedCountryCode: 'gh');

    expect(find.byKey(const ValueKey('country-GH')), findsOneWidget);
    expect(find.text('Kenya'), findsNothing);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(submitted, ['GH']);
  });
}
