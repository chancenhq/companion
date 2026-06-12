import 'package:flutter/foundation.dart';
import '../models/student_account.dart';
import '../services/my_account_service.dart';

class MyAccountProvider with ChangeNotifier {
  final MyAccountService _service = MyAccountService();

  StudentAccount? _account;
  bool _isLoading = false;
  String? _error;

  StudentAccount? get account => _account;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load(String accessToken) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _service.fetchMyAccount(accessToken: accessToken);

    if (result['success'] == true) {
      _account = result['account'] as StudentAccount;
      _error = null;
    } else if (result['not_found'] == true || result['not_configured'] == true) {
      _account = null;
      _error = null; // silently unavailable — UI shows em-dash
    } else {
      _account = null;
      _error = result['error'] as String?;
    }

    _isLoading = false;
    notifyListeners();
  }
}
