import 'package:flutter_test/flutter_test.dart';
import 'package:ip_tv/domain/services/channel_normalizer.dart';

void main() {
  group('ChannelNormalizer', () {
    test('normalizes casing and punctuation', () {
      final normalizer = ChannelNormalizer();
      expect(normalizer.normalizeName(' Bangla-TV!! '), 'bangla tv');
      expect(normalizer.normalizeName('News_24 HD'), 'news 24 hd');
    });

    test('collapses repeated whitespace', () {
      final normalizer = ChannelNormalizer();
      expect(normalizer.normalizeName('  A   B  C  '), 'a b c');
    });
  });
}
