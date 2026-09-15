import 'package:flutter/foundation.dart';
import '../models/student_account.dart';
import '../services/my_account_service.dart';

class MyAccountProvider with ChangeNotifier {
  final MyAccountService _service = MyAccountService();

  StudentAccount? _account;
  bool _isLoading = false;
  bool _loaded = false;
  bool _notFound = false;
  bool _unavailable = false;
  String? _error;

  StudentAccount? get account => _account;
  bool get isLoading => _isLoading;
  bool get loaded => _loaded;
  /// True when the API returned 404 — email is not in the Chancen ISA database.
  bool get notFound => _notFound;
  /// True when the API returned 503 — Metabase is not configured or is down.
  bool get unavailable => _unavailable;
  String? get error => _error;

  Future<void> load(String apiKey) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    _notFound = false;
    _unavailable = false;
    notifyListeners();

    try {
      _account = await _service.fetchMyAccount(apiKey);
      _loaded = true;
    } on AccountNotFoundException {
      _notFound = true;
      _loaded = true;
    } on AccountServiceUnavailableException {
      _unavailable = true;
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
