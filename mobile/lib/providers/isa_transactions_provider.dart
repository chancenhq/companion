import 'package:flutter/foundation.dart';
import '../models/isa_transaction.dart';
import '../services/isa_transactions_service.dart';
import '../services/my_account_service.dart' show EmailVerificationRequiredException;

class IsaTransactionsProvider with ChangeNotifier {
  IsaTransactionsProvider({IsaTransactionsService? service})
      : _service = service ?? IsaTransactionsService();

  final IsaTransactionsService _service;

  List<IsaTransaction>? _transactions;
  bool _isLoading = false;
  bool _loaded = false;
  bool _unavailable = false;
  bool _networkError = false;
  bool _upstreamError = false;
  bool _verificationRequired = false;
  DateTime? _lastSyncedAt;

  List<IsaTransaction>? get transactions => _transactions;
  bool get isLoading => _isLoading;
  bool get loaded => _loaded;
  bool get unavailable => _unavailable;
  /// True when the device has no network or the request timed out.
  bool get networkError => _networkError;
  /// True when the server returned an unexpected error (e.g. 502 from Metabase).
  bool get upstreamError => _upstreamError;
  /// True when the API locked the data behind email verification.
  bool get verificationRequired => _verificationRequired;
  /// UTC timestamp of the last successful data fetch, null if never loaded.
  DateTime? get lastSyncedAt => _lastSyncedAt;

  Future<void> load(String accessToken) async {
    if (_isLoading) return;
    _isLoading = true;
    // Clear error flags but retain _transactions so a failed refresh keeps the
    // last-good list visible behind a stale banner.
    _unavailable = false;
    _networkError = false;
    _upstreamError = false;
    _verificationRequired = false;
    notifyListeners();

    try {
      _transactions = await _service.fetchTransactions(accessToken);
      _loaded = true;
      _lastSyncedAt = DateTime.now();
    } on EmailVerificationRequiredException {
      _verificationRequired = true;
      _loaded = true;
    } on IsaTransactionsUnavailableException {
      _unavailable = true;
      _loaded = true;
    } on IsaTransactionsNetworkException {
      _networkError = true;
      _loaded = true;
    } on IsaTransactionsUpstreamException {
      _upstreamError = true;
      _loaded = true;
    } catch (e) {
      _upstreamError = true;
      _loaded = true;
      debugPrint('IsaTransactionsProvider.load error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
