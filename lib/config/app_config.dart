import 'package:flutter/foundation.dart';

class AppConfig {
  static const String playlistUrl =
      'https://raw.githubusercontent.com/FunctionError/PiratesTv/main/combined_playlist.m3u';
  static const String _defaultTarget =
      String.fromEnvironment('TARGET', defaultValue: 'mobile');
  static String? _targetOverride;

  static String get target => _targetOverride ?? _defaultTarget;
  static bool get isTv => target == 'tv';

  @visibleForTesting
  static void setTargetForTests(String? target) {
    _targetOverride = target;
  }

  @visibleForTesting
  static void clearTargetOverride() {
    _targetOverride = null;
  }
}
