import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ip_tv/adapters/outbound/shared_prefs_channel_store.dart';
import 'package:ip_tv/application/channel_catalog_service.dart';
import 'package:ip_tv/domain/entities/channel.dart';
import 'package:ip_tv/domain/ports/channel_assets_port.dart';
import 'package:ip_tv/domain/ports/playlist_source_port.dart';
import 'package:ip_tv/domain/services/channel_normalizer.dart';
import 'package:ip_tv/domain/services/playlist_parser.dart';
import 'package:ip_tv/provider/channels_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChannelsProvider integration', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('fetchM3UFile merges saved order with custom channels', () async {
      final filteredNames =
          _loadYamlNames('assets/filtered_ordered_channels.yml');
      final allNames =
          _loadYamlNames('assets/all_channels_available.yml');
      expect(filteredNames, isNotEmpty);
      expect(allNames, isNotEmpty);

      final provider = ChannelsProvider();
      final allKeys =
          allNames.map(provider.normalizeName).where((key) => key.isNotEmpty);
      final allSet = allKeys.toSet();
      for (final name in filteredNames) {
        final key = provider.normalizeName(name);
        expect(allSet.contains(key), isTrue,
            reason: 'Missing in all_channels_available.yml: $name');
      }

      final orderedNames = filteredNames.take(2).toList();
      expect(orderedNames.length, greaterThanOrEqualTo(2));

      final customChannel = Channel(
        name: 'Custom Stream',
        logoUrl: 'https://example.com/custom.png',
        streamUrl: 'https://example.com/custom.m3u8',
      );
      await provider.addCustomChannel(customChannel);

      await provider.saveChannelOrder(
        [
          customChannel,
          for (final name in orderedNames)
            Channel(
              name: name,
              logoUrl: 'logo',
              streamUrl: 'stream',
            ),
        ],
      );

      final playlistText = _buildPlaylistFor(orderedNames);
      final store = SharedPrefsChannelStore();
      final catalog = ChannelCatalogService(
        playlistSource: _FakePlaylistSource(playlistText),
        assetsPort: _NoopAssetsPort(),
        orderPort: store,
        customChannelsPort: store,
        playlistParser: PlaylistParser(),
        normalizer: ChannelNormalizer(),
      );
      final testProvider = ChannelsProvider(catalog: catalog);
      await testProvider.addCustomChannel(customChannel);
      await testProvider.saveChannelOrder([
        customChannel,
        for (final name in orderedNames)
          Channel(
            name: name,
            logoUrl: 'logo',
            streamUrl: 'stream',
          ),
      ]);

      final result = await testProvider.fetchM3UFile();
      expect(result.length, greaterThanOrEqualTo(3));
      final orderedResultNames = result.take(3).map((c) => c.name).toList();
      expect(orderedResultNames, [
        customChannel.name,
        orderedNames[0],
        orderedNames[1],
      ]);
      expect(result.first.streamUrl, customChannel.streamUrl);
      final firstRemote = result[1];
      expect(firstRemote.streamUrl.trim().isNotEmpty, isTrue);
    });
  });
}

List<String> _loadYamlNames(String path) {
  final raw = File(path).readAsStringSync();
  final data = loadYaml(raw);
  if (data is! YamlMap) {
    return [];
  }
  final rawChannels = data['channels'];
  if (rawChannels is! YamlList) {
    return [];
  }

  final result = <String>[];
  for (final entry in rawChannels) {
    if (entry == null) {
      continue;
    }
    final name = entry.toString().trim();
    if (name.isEmpty) {
      continue;
    }
    result.add(name);
  }
  return result;
}

String _buildPlaylistFor(List<String> names) {
  final buffer = StringBuffer('#EXTM3U\n');
  for (var i = 0; i < names.length; i++) {
    buffer.writeln(
        '#EXTINF:-1 tvg-logo="https://example.com/logo.png" group-title="Test",${names[i]}');
    buffer.writeln('https://example.com/${i + 1}.m3u8');
  }
  return buffer.toString();
}

class _FakePlaylistSource implements PlaylistSourcePort {
  _FakePlaylistSource(this._playlistText);

  final String _playlistText;

  @override
  Future<String> fetchPlaylist(String url) async => _playlistText;
}

class _NoopAssetsPort implements ChannelAssetsPort {
  @override
  Future<List<String>> loadNames(String assetPath) async => [];
}
