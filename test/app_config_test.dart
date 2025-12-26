import 'package:flutter_test/flutter_test.dart';

import 'package:ip_tv/config/app_config.dart';

void main() {
  tearDown(() {
    AppConfig.clearTargetOverride();
  });

  test('useTvLayout returns true for tv target', () {
    AppConfig.setTargetForTests('tv');
    expect(AppConfig.useTvLayout(isWebOverride: false), isTrue);
  });

  test('useTvLayout returns true for web override', () {
    AppConfig.setTargetForTests('mobile');
    expect(AppConfig.useTvLayout(isWebOverride: true), isTrue);
  });

  test('useTvLayout returns false for mobile non-web', () {
    AppConfig.setTargetForTests('mobile');
    expect(AppConfig.useTvLayout(isWebOverride: false), isFalse);
  });
}
