import 'package:flutter_test/flutter_test.dart';
import 'package:ip_tv/application/channel_catalog_service.dart';
import 'package:ip_tv/domain/entities/channel.dart';
import 'package:ip_tv/domain/ports/channel_assets_port.dart';
import 'package:ip_tv/domain/ports/channel_order_port.dart';
import 'package:ip_tv/domain/ports/custom_channels_port.dart';
import 'package:ip_tv/domain/ports/playlist_source_port.dart';

void main() {
  group('ChannelCatalogService', () {
    test('mergeOrderedChannels prefers custom and preserves order', () {
      final repository = ChannelCatalogService(
        playlistSource: _NoopPlaylistSource(),
        assetsPort: _NoopAssetsPort(),
        orderPort: _NoopOrderPort(),
        customChannelsPort: _NoopCustomChannelsPort(),
      );
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

class _NoopPlaylistSource implements PlaylistSourcePort {
  @override
  Future<String> fetchPlaylist(String url) async => '';
}

class _NoopAssetsPort implements ChannelAssetsPort {
  @override
  Future<List<String>> loadNames(String assetPath) async => [];
}

class _NoopOrderPort implements ChannelOrderPort {
  @override
  Future<List<String>> loadOrder(String key) async => [];

  @override
  Future<void> saveOrder(String key, List<String> names) async {}
}

class _NoopCustomChannelsPort implements CustomChannelsPort {
  @override
  Future<List<Channel>> loadCustomChannels(
    String key, {
    required String defaultLogoUrl,
  }) async =>
      [];

  @override
  Future<void> saveCustomChannels(String key, List<Channel> channels) async {}
}
