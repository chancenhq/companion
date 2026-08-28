import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sure_mobile/models/custom_proxy_header.dart';
import 'package:sure_mobile/services/custom_proxy_headers_service.dart';

const _backendUrl = 'https://example.com';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('saves and loads custom proxy headers per backend URL', () async {
    final service = CustomProxyHeadersService.instance;
    final headers = [
      CustomProxyHeader(name: 'X-Auth-Id', value: 'id'),
      CustomProxyHeader(name: 'X-Auth-Secret', value: 'secret'),
    ];

    await service.saveHeaders(headers, backendUrl: _backendUrl);

    expect(await service.loadHeaders(backendUrl: _backendUrl), headers);
  });

  test('headers are isolated between different backend URLs', () async {
    final service = CustomProxyHeadersService.instance;
    final headers = [CustomProxyHeader(name: 'X-Staging-Key', value: 'secret')];

    await service.saveHeaders(headers, backendUrl: 'https://staging.example.com');

    expect(
      await service.loadHeaders(backendUrl: 'https://prod.example.com'),
      isEmpty,
    );
  });

  test('drops incomplete and duplicate headers, keeping the last value', () async {
    final service = CustomProxyHeadersService.instance;

    await service.saveHeaders([
      CustomProxyHeader(name: 'X-Auth-Id', value: 'old'),
      CustomProxyHeader(name: '', value: 'ignored'),
      CustomProxyHeader(name: 'X-Auth-Id', value: 'new'),
      CustomProxyHeader(name: 'X-Empty', value: ''),
    ], backendUrl: _backendUrl);

    expect(await service.loadHeaders(backendUrl: _backendUrl), [
      CustomProxyHeader(name: 'X-Auth-Id', value: 'new'),
    ]);
  });

  test('returns an empty list for invalid stored json', () async {
    const storage = FlutterSecureStorage();
    // Write bad JSON directly to the v2 key for this URL
    final key = 'custom_proxy_headers_v2_${_backendUrl.hashCode}';
    await storage.write(key: key, value: 'not json');

    expect(
      await CustomProxyHeadersService.instance.loadHeaders(backendUrl: _backendUrl),
      isEmpty,
    );
  });

  test('migrates legacy single-key headers to the URL-scoped key on first load', () async {
    const storage = FlutterSecureStorage();
    final headers = [CustomProxyHeader(name: 'X-Legacy', value: 'val')];
    await storage.write(
      key: 'custom_proxy_headers',
      value: '[{"name":"X-Legacy","value":"val"}]',
    );

    final loaded = await CustomProxyHeadersService.instance.loadHeaders(backendUrl: _backendUrl);
    expect(loaded, headers);

    // Legacy key should be gone after migration
    expect(await storage.read(key: 'custom_proxy_headers'), isNull);
  });
}
