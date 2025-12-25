import 'package:flutter_test/flutter_test.dart';
import 'package:ip_tv/adapters/outbound/asset_channel_names_source.dart';

void main() {
  group('AssetChannelNamesSource', () {
    test('parseNames reads channels from YAML map', () {
      final source = AssetChannelNamesSource();
      const raw = '''
channels:
  - "One"
  - ""
  - "Two"
''';
      final result = source.parseNames(raw);
      expect(result, ['One', 'Two']);
    });

    test('parseNames reads channels from YAML list', () {
      final source = AssetChannelNamesSource();
      const raw = '''
- Alpha
- Beta
''';
      final result = source.parseNames(raw);
      expect(result, ['Alpha', 'Beta']);
    });
  });
}
