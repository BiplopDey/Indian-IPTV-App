import 'package:flutter_test/flutter_test.dart';
import 'package:ip_tv/application/channel_catalog_service.dart';
import 'package:ip_tv/domain/entities/channel.dart';
import 'package:ip_tv/domain/ports/channel_assets_port.dart';
import 'package:ip_tv/domain/ports/channel_order_port.dart';
import 'package:ip_tv/domain/ports/custom_channels_port.dart';
import 'package:ip_tv/domain/ports/playlist_source_port.dart';
import 'package:ip_tv/domain/services/channel_normalizer.dart';
import 'package:ip_tv/domain/services/playlist_parser.dart';

void main() {
  group('ChannelCatalogService', () {
    test('loadPreferredNames returns stored order when available', () async {
      final orderPort = _FakeOrderPort(['Stored']);
      final assetsPort = _FakeAssetsPort(['Fallback']);
      final service = _buildService(
        orderPort: orderPort,
        assetsPort: assetsPort,
      );

      final result = await service.loadPreferredNames(
        assetPath: 'assets/filtered_ordered_channels.yml',
        orderKey: 'order_key',
      );

      expect(result, ['Stored']);
      expect(orderPort.loadCalls, 1);
      expect(assetsPort.loadCalls, 0);
    });

    test('loadPreferredNames falls back to assets when order empty', () async {
      final orderPort = _FakeOrderPort([]);
      final assetsPort = _FakeAssetsPort(['Asset One']);
      final service = _buildService(
        orderPort: orderPort,
        assetsPort: assetsPort,
      );

      final result = await service.loadPreferredNames(
        assetPath: 'assets/filtered_ordered_channels.yml',
        orderKey: 'order_key',
      );

      expect(result, ['Asset One']);
      expect(orderPort.loadCalls, 1);
      expect(assetsPort.loadCalls, 1);
    });

    test('fetchRemoteIndex caches responses and respects forceRefresh',
        () async {
      const playlist = '''
#EXTM3U
#EXTINF:-1,Channel One
https://example.com/one.m3u8
#EXTINF:-1,Channel One
https://example.com/one-dup.m3u8
''';
      final source = _FakePlaylistSource(playlist);
      final service = _buildService(playlistSource: source);

      final first = await service.fetchRemoteIndex(
        playlistUrl: 'https://example.com/playlist.m3u',
        defaultLogoUrl: 'assets/images/tv-icon.png',
      );
      final second = await service.fetchRemoteIndex(
        playlistUrl: 'https://example.com/playlist.m3u',
        defaultLogoUrl: 'assets/images/tv-icon.png',
      );
      final refreshed = await service.fetchRemoteIndex(
        playlistUrl: 'https://example.com/playlist.m3u',
        defaultLogoUrl: 'assets/images/tv-icon.png',
        forceRefresh: true,
      );

      expect(first.length, 1);
      expect(second.length, 1);
      expect(refreshed.length, 1);
      expect(source.calls, 2);
    });

    test('fetchRemoteChannelsSorted orders channels by name', () async {
      const playlist = '''
#EXTM3U
#EXTINF:-1,Zeta News
https://example.com/zeta.m3u8
#EXTINF:-1,Alpha News
https://example.com/alpha.m3u8
''';
      final source = _FakePlaylistSource(playlist);
      final service = _buildService(playlistSource: source);

      final result = await service.fetchRemoteChannelsSorted(
        playlistUrl: 'https://example.com/playlist.m3u',
        defaultLogoUrl: 'assets/images/tv-icon.png',
      );

      expect(result.map((c) => c.name).toList(), ['Alpha News', 'Zeta News']);
      expect(source.calls, 1);
    });
  });
}

ChannelCatalogService _buildService({
  PlaylistSourcePort? playlistSource,
  ChannelAssetsPort? assetsPort,
  ChannelOrderPort? orderPort,
  CustomChannelsPort? customChannelsPort,
}) {
  return ChannelCatalogService(
    playlistSource: playlistSource ?? _FakePlaylistSource(''),
    assetsPort: assetsPort ?? _FakeAssetsPort([]),
    orderPort: orderPort ?? _FakeOrderPort([]),
    customChannelsPort: customChannelsPort ?? _FakeCustomChannelsPort([]),
    playlistParser: PlaylistParser(),
    normalizer: ChannelNormalizer(),
  );
}

class _FakePlaylistSource implements PlaylistSourcePort {
  _FakePlaylistSource(this._playlistText);

  final String _playlistText;
  int calls = 0;

  @override
  Future<String> fetchPlaylist(String url) async {
    calls += 1;
    return _playlistText;
  }
}

class _FakeAssetsPort implements ChannelAssetsPort {
  _FakeAssetsPort(this._names);

  final List<String> _names;
  int loadCalls = 0;

  @override
  Future<List<String>> loadNames(String assetPath) async {
    loadCalls += 1;
    return _names;
  }
}

class _FakeOrderPort implements ChannelOrderPort {
  _FakeOrderPort(this._stored);

  final List<String> _stored;
  int loadCalls = 0;
  List<String> saved = [];

  @override
  Future<List<String>> loadOrder(String key) async {
    loadCalls += 1;
    return _stored;
  }

  @override
  Future<void> saveOrder(String key, List<String> names) async {
    saved = List<String>.from(names);
  }
}

class _FakeCustomChannelsPort implements CustomChannelsPort {
  _FakeCustomChannelsPort(this._channels);

  final List<Channel> _channels;

  @override
  Future<List<Channel>> loadCustomChannels(
    String key, {
    required String defaultLogoUrl,
  }) async =>
      _channels;

  @override
  Future<void> saveCustomChannels(String key, List<Channel> channels) async {}
}
