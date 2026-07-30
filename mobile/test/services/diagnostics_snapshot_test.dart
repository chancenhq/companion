import 'package:flutter_test/flutter_test.dart';
import 'package:sure_mobile/services/diagnostics_snapshot.dart';

void main() {
  test('formats diagnostics for clipboard sharing', () {
    const snapshot = DiagnosticsSnapshot(
      appVersion: '0.6.9 (20260402)',
      platform: 'android',
      backendUrl: 'https://companion-prod.chancen.tech',
      authMode: 'OAuth token',
      isAuthenticated: true,
      uiLayout: 'intro',
      aiEnabled: false,
      customProxyHeaderCount: 2,
      biometricLockEnabled: true,
    );

    expect(
      snapshot.toClipboardText(),
      [
        'Chancen Companion diagnostics',
        'App version: 0.6.9 (20260402)',
        'Platform: android',
        'Backend URL: https://companion-prod.chancen.tech',
        'Auth mode: OAuth token',
        'Authenticated: yes',
        'UI layout: intro',
        'AI enabled: no',
        'Custom proxy headers: 2',
        'Biometric lock: enabled',
      ].join('\n'),
    );
  });

  test('uses unknown for missing optional values', () {
    const snapshot = DiagnosticsSnapshot(
      appVersion: 'unknown',
      platform: 'linux',
      backendUrl: 'https://example.test',
      authMode: 'API key',
      isAuthenticated: false,
      uiLayout: null,
      aiEnabled: null,
      customProxyHeaderCount: 0,
      biometricLockEnabled: false,
    );

    expect(snapshot.toClipboardText(), contains('UI layout: unknown'));
    expect(snapshot.toClipboardText(), contains('AI enabled: unknown'));
    expect(snapshot.toClipboardText(), contains('Authenticated: no'));
    expect(snapshot.toClipboardText(), contains('Biometric lock: disabled'));
  });
}
