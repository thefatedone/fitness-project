import 'package:flutter_test/flutter_test.dart';
import 'package:nutrimind/core/config/app_config.dart';

void main() {
  test('explicit profile backend overrides a stale on-device debug URL', () {
    AppConfig.setRuntimeOverride('http://old-device-setting:8000');
    addTearDown(() => AppConfig.setRuntimeOverride(null));
    if (AppConfig.compiledApiBaseUrl.isEmpty) {
      expect(AppConfig.apiBaseUrl, 'http://old-device-setting:8000/api/v1');
    } else {
      final base = AppConfig.compiledApiBaseUrl.replaceFirst(
        RegExp(r'/+$'),
        '',
      );
      expect(
        AppConfig.apiBaseUrl,
        base.endsWith('/api/v1') ? base : '$base/api/v1',
      );
    }
  });
}
