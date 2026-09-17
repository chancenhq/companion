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
  bool _networkError = false;
  bool _upstreamError = false;

  StudentAccount? get account => _account;
  bool get isLoading => _isLoading;
  bool get loaded => _loaded;
  bool get notFound => _notFound;
  bool get unavailable => _unavailable;
  /// True when the device has no network or the request timed out.
  bool get networkError => _networkError;
  /// True when the server returned an unexpected error (e.g. 502 from Metabase).
  bool get upstreamError => _upstreamError;

  Future<void> load(String apiKey) async {
    if (_isLoading) return;
    _isLoading = true;
    _notFound = false;
    _unavailable = false;
    _networkError = false;
    _upstreamError = false;
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
    } on AccountNetworkException {
      _networkError = true;
      _loaded = true;
    } on AccountUpstreamException {
      _upstreamError = true;
      _loaded = true;
    } catch (e) {
      _upstreamError = true;
      _loaded = true;
      debugPrint('MyAccountProvider.load error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
