import 'package:flutter/material.dart';

import '../data/channel_repository.dart';
import '../data/playlist_parser.dart';
import '../model/channel.dart';
import '../utils/channel_normalizer.dart';

class ChannelsProvider with ChangeNotifier {
  static const String playlistUrl =
      'https://raw.githubusercontent.com/FunctionError/PiratesTv/main/combined_playlist.m3u';
  static const String _filteredChannelsAsset =
      'assets/filtered_ordered_channels.yml';
  static const String _customChannelsKey = 'custom_channels_v1';
  static const String _orderKey = 'channel_order_v1';

  List<Channel> channels = [];
  List<Channel> filteredChannels = [];
  List<Channel> customChannels = [];
  String sourceUrl = playlistUrl;

  late final PlaylistParser _playlistParser;
  late final ChannelNormalizer _normalizer;
  late final ChannelRepository _repository;

  ChannelsProvider({
    PlaylistParser? playlistParser,
    ChannelNormalizer? normalizer,
    ChannelRepository? repository,
  }) {
    _playlistParser = playlistParser ?? PlaylistParser();
    _normalizer = normalizer ?? ChannelNormalizer();
    _repository = repository ??
        ChannelRepository(
          playlistParser: _playlistParser,
          normalizer: _normalizer,
        );
  }

  Future<List<Channel>> fetchM3UFile() async {
    final orderedNames = await loadPreferredChannelNames();
    customChannels = await loadCustomChannels();
    final remoteIndex = await _repository.fetchRemoteIndex(
      playlistUrl: sourceUrl,
      defaultLogoUrl: getDefaultLogoUrl(),
    );
    final result = _repository.mergeOrderedChannels(
      orderedNames: orderedNames,
      customChannels: customChannels,
      remoteIndex: remoteIndex,
      defaultLogoUrl: getDefaultLogoUrl(),
    );
    channels = result;
    filteredChannels = result;
    return channels;
  }

  String getDefaultLogoUrl() {
    return 'assets/images/tv-icon.png';
  }

  String? extractChannelName(String line) {
    return _playlistParser.extractChannelName(line);
  }

  String? extractLogoUrl(String line) {
    return _playlistParser.extractLogoUrl(line);
  }

  String? extractGroupTitle(String line) {
    return _playlistParser.extractGroupTitle(line);
  }

  bool isValidUrl(String url) {
    return _playlistParser.isValidUrl(url);
  }

  String normalizeName(String value) {
    return _normalizer.normalizeName(value);
  }

  List<Channel> filterChannels(String query) {
    filteredChannels = channels
        .where((channel) =>
            channel.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return filteredChannels;
  }

  Future<List<String>> loadFilteredChannelNames() async {
    return _repository.loadFilteredNames(_filteredChannelsAsset);
  }

  Future<List<String>> loadPreferredChannelNames() async {
    return _repository.loadPreferredNames(
      assetPath: _filteredChannelsAsset,
      orderKey: _orderKey,
    );
  }

  Future<List<Channel>> loadCustomChannels() async {
    return _repository.loadCustomChannels(
      _customChannelsKey,
      defaultLogoUrl: getDefaultLogoUrl(),
    );
  }

  Future<void> saveChannelOrder(List<Channel> ordered) async {
    final names = ordered.map((channel) => channel.name).toList();
    await _repository.savePreferredNames(_orderKey, names);
  }

  Future<void> addCustomChannel(Channel channel) async {
    final key = normalizeName(channel.name);
    if (key.isEmpty) {
      return;
    }
    customChannels.removeWhere(
        (entry) => normalizeName(entry.name) == key);
    customChannels.add(channel);
    await _repository.saveCustomChannels(_customChannelsKey, customChannels);
  }

  Future<void> removeCustomChannelByName(String name) async {
    final key = normalizeName(name);
    if (key.isEmpty) {
      return;
    }
    final before = customChannels.length;
    customChannels
        .removeWhere((entry) => normalizeName(entry.name) == key);
    if (customChannels.length != before) {
      await _repository.saveCustomChannels(_customChannelsKey, customChannels);
    }
  }

  Future<List<Channel>> fetchRemoteChannels({bool forceRefresh = false}) {
    return _repository.fetchRemoteChannelsSorted(
      playlistUrl: sourceUrl,
      defaultLogoUrl: getDefaultLogoUrl(),
      forceRefresh: forceRefresh,
    );
  }
}
