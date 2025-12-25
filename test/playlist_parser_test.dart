import 'package:flutter_test/flutter_test.dart';
import 'package:ip_tv/domain/services/playlist_parser.dart';

void main() {
  group('PlaylistParser', () {
    test('extracts channel metadata from EXTINF', () {
      final parser = PlaylistParser();
      const line =
          '#EXTINF:-1 tvg-logo="https://example.com/logo.png" group-title="News",Example News';
      expect(parser.extractChannelName(line), 'Example News');
      expect(parser.extractLogoUrl(line), 'https://example.com/logo.png');
      expect(parser.extractGroupTitle(line), 'News');
    });

    test('parses channels in order', () {
      final parser = PlaylistParser();
      const playlist = '''
#EXTM3U
#EXTINF:-1 tvg-logo="https://example.com/one.png" group-title="General",Channel One
https://example.com/one.m3u8
#EXTINF:-1 group-title="Sports",Channel Two
https://example.com/two.m3u8
''';
      final result =
          parser.parse(playlist, defaultLogoUrl: 'assets/images/tv-icon.png');
      expect(result.length, 2);
      expect(result.first.name, 'Channel One');
      expect(result.first.logoUrl, 'https://example.com/one.png');
      expect(result.first.groupTitle, 'General');
      expect(result[1].name, 'Channel Two');
      expect(result[1].logoUrl, 'assets/images/tv-icon.png');
      expect(result[1].groupTitle, 'Sports');
    });
  });
}
