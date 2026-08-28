import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/custom_proxy_header.dart';

class CustomProxyHeadersService {
  // Legacy single-backend key kept for migration reads only.
  static const String _legacyKey = 'custom_proxy_headers';

  static CustomProxyHeadersService? _instance;

  CustomProxyHeadersService._();

  static CustomProxyHeadersService get instance {
    _instance ??= CustomProxyHeadersService._();
    return _instance!;
  }

  // Per-backend storage key derived from the URL so staging/prod headers
  // never bleed into each other after a quick-switch.
  static String _keyForUrl(String backendUrl) =>
      'custom_proxy_headers_v2_${backendUrl.hashCode}';

  Future<List<CustomProxyHeader>> loadHeaders({required String backendUrl}) async {
    const storage = FlutterSecureStorage();
    try {
      final key = _keyForUrl(backendUrl);
      var raw = await storage.read(key: key);

      // One-time migration: promote legacy single-key headers to the URL-scoped
      // key so existing users don't lose their headers on first upgrade.
      if (raw == null || raw.isEmpty) {
        final legacy = await storage.read(key: _legacyKey);
        if (legacy != null && legacy.isNotEmpty) {
          await storage.write(key: key, value: legacy);
          await storage.delete(key: _legacyKey);
          raw = legacy;
        }
      }

      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return CustomProxyHeader.sanitize(
        decoded
            .whereType<Map>()
            .map((item) => CustomProxyHeader.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHeaders(List<CustomProxyHeader> headers, {required String backendUrl}) async {
    const storage = FlutterSecureStorage();
    final sanitized = CustomProxyHeader.sanitize(headers);
    await storage.write(
      key: _keyForUrl(backendUrl),
      value: jsonEncode(sanitized.map((header) => header.toJson()).toList()),
    );
  }
}
