import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// App-wide signals from API responses that change what the signed-in user
/// may see. Data services report responses here; [AuthProvider] listens.
///
/// - 401: the session was revoked (password reset, Google/Apple link) or
///   expired beyond refresh, so the app signs out.
/// - 403 `email_verification_required`: the server locks financial and
///   Chancen Account data until the email is verified (issue #106).
class AuthEvents {
  AuthEvents._();

  static final AuthEvents instance = AuthEvents._();

  static const String emailVerificationRequiredCode = 'email_verification_required';

  final StreamController<void> _unauthorized = StreamController<void>.broadcast();
  final StreamController<void> _emailVerificationRequired = StreamController<void>.broadcast();

  Stream<void> get onUnauthorized => _unauthorized.stream;
  Stream<void> get onEmailVerificationRequired => _emailVerificationRequired.stream;

  /// Reports [response] from an authenticated data endpoint. Don't call this
  /// for sign-in endpoints, where a 401 just means wrong credentials.
  void report(http.Response response) {
    if (response.statusCode == 401) {
      _unauthorized.add(null);
    } else if (isEmailVerificationRequired(response)) {
      _emailVerificationRequired.add(null);
    }
  }

  static bool isEmailVerificationRequired(http.Response response) {
    if (response.statusCode != 403) return false;
    try {
      final body = jsonDecode(response.body);
      return body is Map && body['error'] == emailVerificationRequiredCode;
    } catch (_) {
      return false;
    }
  }
}
