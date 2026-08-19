import 'package:flutter/foundation.dart';
import '../models/student_account.dart';
import '../services/my_account_service.dart';

class MyAccountProvider with ChangeNotifier {
  final MyAccountService _service = MyAccountService();

  StudentAccount? _account;
  bool _isLoading = false;
  bool _loaded = false;
  String? _error;

  StudentAccount? get account => _account;
  bool get isLoading => _isLoading;
  bool get loaded => _loaded;
  String? get error => _error;

  Future<void> load(String apiKey) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _account = await _service.fetchMyAccount(apiKey);
      _loaded = true;
    } catch (e) {
      _error = e.toString();
      debugPrint('MyAccountProvider.load error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
