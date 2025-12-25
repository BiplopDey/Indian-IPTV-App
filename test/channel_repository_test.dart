import 'package:flutter_test/flutter_test.dart';
import 'package:ip_tv/data/channel_repository.dart';
import 'package:ip_tv/model/channel.dart';

void main() {
  group('ChannelRepository', () {
    test('mergeOrderedChannels prefers custom and preserves order', () {
      final repository = ChannelRepository();
      final ordered = ['Channel One', 'Channel Two', 'Channel Three'];
      final custom = [
        Channel(
          name: 'Channel Two',
          logoUrl: 'custom-logo',
          streamUrl: 'https://custom.example/two.m3u8',
          groupTitle: 'Custom',
        ),
        Channel(
          name: 'Channel Extra',
          logoUrl: 'extra-logo',
          streamUrl: 'https://custom.example/extra.m3u8',
        ),
      ];
      final remoteIndex = {
        repository.normalizeName('Channel One'): Channel(
          name: 'Channel One',
          logoUrl: 'remote-logo',
          streamUrl: 'https://remote.example/one.m3u8',
        ),
      };

      final result = repository.mergeOrderedChannels(
        orderedNames: ordered,
        customChannels: custom,
        remoteIndex: remoteIndex,
        defaultLogoUrl: 'assets/images/tv-icon.png',
      );

      expect(result.length, 4);
      expect(result[0].name, 'Channel One');
      expect(result[0].streamUrl, 'https://remote.example/one.m3u8');
      expect(result[1].name, 'Channel Two');
      expect(result[1].streamUrl, 'https://custom.example/two.m3u8');
      expect(result[2].name, 'Channel Three');
      expect(result[2].streamUrl, isEmpty);
      expect(result[3].name, 'Channel Extra');
    });
  });
}
