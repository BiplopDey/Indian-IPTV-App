import 'package:package_info_plus/package_info_plus.dart';

abstract class AppVersionLoader {
  Future<String?> loadAppVersion();
}

class PackageInfoVersionLoader implements AppVersionLoader {
  @override
  Future<String?> loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return null;
    }
  }
}
