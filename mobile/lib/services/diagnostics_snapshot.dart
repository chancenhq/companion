class DiagnosticsSnapshot {
  const DiagnosticsSnapshot({
    required this.appVersion,
    required this.platform,
    required this.backendUrl,
    required this.authMode,
    required this.isAuthenticated,
    required this.uiLayout,
    required this.aiEnabled,
    required this.customProxyHeaderCount,
    required this.biometricLockEnabled,
  });

  final String appVersion;
  final String platform;
  final String backendUrl;
  final String authMode;
  final bool isAuthenticated;
  final String? uiLayout;
  final bool? aiEnabled;
  final int customProxyHeaderCount;
  final bool biometricLockEnabled;

  String toClipboardText() {
    return [
      'Chancen Companion diagnostics',
      'App version: $appVersion',
      'Platform: $platform',
      'Backend URL: $backendUrl',
      'Auth mode: $authMode',
      'Authenticated: ${_formatBool(isAuthenticated)}',
      'UI layout: ${_formatNullable(uiLayout)}',
      'AI enabled: ${_formatNullableBool(aiEnabled)}',
      'Custom proxy headers: $customProxyHeaderCount',
      'Biometric lock: ${biometricLockEnabled ? 'enabled' : 'disabled'}',
    ].join('\n');
  }

  static String _formatNullable(String? value) {
    if (value == null || value.trim().isEmpty) return 'unknown';
    return value;
  }

  static String _formatNullableBool(bool? value) {
    if (value == null) return 'unknown';
    return _formatBool(value);
  }

  static String _formatBool(bool value) => value ? 'yes' : 'no';
}
