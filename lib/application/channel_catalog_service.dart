import '../domain/entities/channel.dart';
import '../domain/ports/channel_assets_port.dart';
import '../domain/ports/channel_order_port.dart';
import '../domain/ports/custom_channels_port.dart';
import '../domain/ports/playlist_source_port.dart';
import '../domain/services/channel_normalizer.dart';
import '../domain/services/playlist_parser.dart';

class ChannelCatalogService {
  ChannelCatalogService({
    required PlaylistSourcePort playlistSource,
    required ChannelAssetsPort assetsPort,
    required ChannelOrderPort orderPort,
    required CustomChannelsPort customChannelsPort,
    ChannelNormalizer? normalizer,
    PlaylistParser? playlistParser,
  })  : _playlistSource = playlistSource,
        _assetsPort = assetsPort,
        _orderPort = orderPort,
        _customChannelsPort = customChannelsPort,
        _normalizer = normalizer ?? ChannelNormalizer(),
        _playlistParser = playlistParser ?? PlaylistParser();

  final PlaylistSourcePort _playlistSource;
  final ChannelAssetsPort _assetsPort;
  final ChannelOrderPort _orderPort;
  final CustomChannelsPort _customChannelsPort;
  final ChannelNormalizer _normalizer;
  final PlaylistParser _playlistParser;

  Map<String, Channel>? _remoteIndex;
  List<Channel>? _remoteChannels;

  String normalizeName(String value) => _normalizer.normalizeName(value);

  Future<List<String>> loadFilteredNames(String assetPath) {
    return _assetsPort.loadNames(assetPath);
  }

  Future<List<String>> loadPreferredNames({
    required String assetPath,
    required String orderKey,
  }) async {
    final stored = await _orderPort.loadOrder(orderKey);
    if (stored.isNotEmpty) {
      return stored;
    }
    return _assetsPort.loadNames(assetPath);
  }

  Future<void> savePreferredNames(String orderKey, List<String> names) {
    return _orderPort.saveOrder(orderKey, names);
  }

  Future<List<Channel>> loadCustomChannels(
    String key, {
    required String defaultLogoUrl,
  }) {
    return _customChannelsPort.loadCustomChannels(
      key,
      defaultLogoUrl: defaultLogoUrl,
    );
  }

  Future<void> saveCustomChannels(String key, List<Channel> channels) {
    return _customChannelsPort.saveCustomChannels(key, channels);
  }

  Future<Map<String, Channel>> fetchRemoteIndex({
    required String playlistUrl,
    required String defaultLogoUrl,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _remoteIndex != null) {
      return _remoteIndex!;
    }
    final text = await _playlistSource.fetchPlaylist(playlistUrl);
    final parsed =
        _playlistParser.parse(text, defaultLogoUrl: defaultLogoUrl);
    final index = <String, Channel>{};
    for (final channel in parsed) {
      final key = _normalizer.normalizeName(channel.name);
      if (key.isEmpty || index.containsKey(key)) {
        continue;
      }
      index[key] = channel;
    }
    _remoteIndex = index;
    return index;
  }

  Future<List<Channel>> fetchRemoteChannelsSorted({
    required String playlistUrl,
    required String defaultLogoUrl,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _remoteChannels != null) {
      return _remoteChannels!;
    }
    final index = await fetchRemoteIndex(
      playlistUrl: playlistUrl,
      defaultLogoUrl: defaultLogoUrl,
      forceRefresh: forceRefresh,
    );
    final channels = index.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _remoteChannels = channels;
    return channels;
  }

  List<Channel> mergeOrderedChannels({
    required List<String> orderedNames,
    required List<Channel> customChannels,
    required Map<String, Channel> remoteIndex,
    required String defaultLogoUrl,
  }) {
    final customIndex = <String, Channel>{};
    for (final channel in customChannels) {
      final key = _normalizer.normalizeName(channel.name);
      if (key.isEmpty || customIndex.containsKey(key)) {
        continue;
      }
      customIndex[key] = channel;
    }

    final result = <Channel>[];
    final seen = <String>{};

    for (final name in orderedNames) {
      final key = _normalizer.normalizeName(name);
      if (key.isEmpty || seen.contains(key)) {
        continue;
      }
      seen.add(key);
      final custom = customIndex[key];
      if (custom != null) {
        result.add(custom);
        continue;
      }
      final remote = remoteIndex[key];
      result.add(
        remote ??
            Channel(
              name: name,
              logoUrl: defaultLogoUrl,
              streamUrl: '',
              groupTitle: '',
            ),
      );
    }

    for (final channel in customChannels) {
      final key = _normalizer.normalizeName(channel.name);
      if (key.isEmpty || seen.contains(key)) {
        continue;
      }
      seen.add(key);
      result.add(channel);
    }

    return result;
  }
}
