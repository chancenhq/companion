import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sure_mobile/services/auth_events.dart';

void main() {
  group('AuthEvents.isEmailVerificationRequired', () {
    test('matches the server lock response', () {
      final response = http.Response(
        '{"error":"email_verification_required","message":"Verify your email to see your Chancen Account","action":"resend_email"}',
        403,
      );
      expect(AuthEvents.isEmailVerificationRequired(response), isTrue);
    });

    test('ignores other 403s and non-JSON bodies', () {
      expect(AuthEvents.isEmailVerificationRequired(http.Response('{"error":"insufficient_scope"}', 403)), isFalse);
      expect(AuthEvents.isEmailVerificationRequired(http.Response('Forbidden', 403)), isFalse);
      expect(AuthEvents.isEmailVerificationRequired(http.Response('{"error":"email_verification_required"}', 500)), isFalse);
    });
  });

  group('AuthEvents.report', () {
    test('signals sign-out on 401 and the lock on 403', () async {
      final unauthorized = AuthEvents.instance.onUnauthorized.first;
      AuthEvents.instance.report(http.Response('{"error":"unauthorized"}', 401));
      await expectLater(unauthorized, completes);

      final locked = AuthEvents.instance.onEmailVerificationRequired.first;
      AuthEvents.instance.report(http.Response('{"error":"email_verification_required"}', 403));
      await expectLater(locked, completes);
    });
  });
}
