import 'package:flutter_test/flutter_test.dart';
import 'package:ip_tv/model/channel.dart';
import 'package:ip_tv/provider/channels_provider.dart';

void main() {
  group('ChannelsProvider helpers', () {
    test('extractChannelName returns the last comma segment', () {
      final provider = ChannelsProvider();
      const line = '#EXTINF:-1,My Channel HD';
      expect(provider.extractChannelName(line), 'My Channel HD');
    });

    test('extractLogoUrl returns the first valid quoted URL', () {
      final provider = ChannelsProvider();
      const line =
          '#EXTINF:-1 tvg-logo="https://example.com/logo.png",Channel';
      expect(provider.extractLogoUrl(line), 'https://example.com/logo.png');
    });

    test('isValidUrl accepts http/https only', () {
      final provider = ChannelsProvider();
      expect(provider.isValidUrl('http://example.com'), true);
      expect(provider.isValidUrl('https://example.com'), true);
      expect(provider.isValidUrl('ftp://example.com'), false);
    });

    test('filterChannels matches case-insensitively', () {
      final provider = ChannelsProvider();
      provider.channels = [
        Channel(
          name: 'News One',
          logoUrl: 'logo1',
          streamUrl: 'stream1',
        ),
        Channel(
          name: 'Sports Live',
          logoUrl: 'logo2',
          streamUrl: 'stream2',
        ),
        Channel(
          name: 'Daily NEWS 24',
          logoUrl: 'logo3',
          streamUrl: 'stream3',
        ),
      ];

      final results = provider.filterChannels('news');
      expect(results.length, 2);
      expect(results[0].name, 'News One');
      expect(results[1].name, 'Daily NEWS 24');
    });

    test('getDefaultLogoUrl returns the asset path', () {
      final provider = ChannelsProvider();
      expect(provider.getDefaultLogoUrl(), 'assets/images/tv-icon.png');
    });
  });
}
