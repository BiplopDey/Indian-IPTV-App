import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';

import '../model/channel.dart';

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
  Map<String, Channel>? _remoteIndex;
  List<Channel>? _remoteChannels;
  String sourceUrl = playlistUrl;

  Future<List<Channel>> fetchM3UFile() async {
    final orderedNames = await loadPreferredChannelNames();
    customChannels = await loadCustomChannels();
    final customIndex = <String, Channel>{};
    for (final channel in customChannels) {
      final key = normalizeName(channel.name);
      if (key.isEmpty || customIndex.containsKey(key)) {
        continue;
      }
      customIndex[key] = channel;
    }
    final remoteIndex = await _fetchRemoteChannels();
    final result = <Channel>[];
    final seen = <String>{};

    for (final name in orderedNames) {
      final key = normalizeName(name);
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
      result.add(remote ??
          Channel(
            name: name,
            logoUrl: getDefaultLogoUrl(),
            streamUrl: '',
            groupTitle: '',
          ));
    }

    for (final channel in customChannels) {
      final key = normalizeName(channel.name);
      if (key.isEmpty || seen.contains(key)) {
        continue;
      }
      seen.add(key);
      result.add(channel);
    }

    channels = result;
    filteredChannels = result;
    return channels;
  }

  String getDefaultLogoUrl() {
    return 'assets/images/tv-icon.png';
  }

  String? extractChannelName(String line) {
    List<String> parts = line.split(',');
    return parts.last;
  }

  String? extractLogoUrl(String line) {
    List<String> parts = line.split('"');
    if (parts.length > 1 && isValidUrl(parts[1])) {
      return parts[1];
    } else if (parts.length > 5 && isValidUrl(parts[5])) {
      return parts[5];
    }
    return null;
  }

  String? extractGroupTitle(String line) {
    final matches = RegExp(r'group-title="([^"]*)"').allMatches(line);
    for (final match in matches) {
      final value = match.group(1);
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  bool isValidUrl(String url) {
    return url.startsWith('https') || url.startsWith('http');
  }

  String normalizeName(String value) {
    final lower = value.toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    return cleaned.replaceAll(RegExp(r'\s+'), ' ');
  }

  List<Channel> filterChannels(String query) {
    filteredChannels = channels
        .where((channel) =>
            channel.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return filteredChannels;
  }

  Future<List<String>> loadFilteredChannelNames() async {
    return _loadChannelNamesFromAsset(_filteredChannelsAsset);
  }

  Future<List<String>> loadPreferredChannelNames() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_orderKey);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    return loadFilteredChannelNames();
  }

  Future<List<Channel>> loadCustomChannels() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customChannelsKey);
    if (raw == null || raw.trim().isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return [];
    }
    final result = <Channel>[];
    for (final entry in decoded) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }
      final channel = _channelFromJson(entry);
      if (channel != null) {
        result.add(channel);
      }
    }
    return result;
  }

  Future<void> saveChannelOrder(List<Channel> ordered) async {
    final prefs = await SharedPreferences.getInstance();
    final names = ordered.map((channel) => channel.name).toList();
    await prefs.setStringList(_orderKey, names);
  }

  Future<void> addCustomChannel(Channel channel) async {
    final key = normalizeName(channel.name);
    if (key.isEmpty) {
      return;
    }
    customChannels.removeWhere(
        (entry) => normalizeName(entry.name) == key);
    customChannels.add(channel);
    await _saveCustomChannels(customChannels);
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
      await _saveCustomChannels(customChannels);
    }
  }

  Future<void> _saveCustomChannels(List<Channel> channels) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
        channels.map((channel) => _channelToJson(channel)).toList());
    await prefs.setString(_customChannelsKey, payload);
  }

  Channel? _channelFromJson(Map<String, dynamic> data) {
    final name = data['name'];
    final streamUrl = data['streamUrl'];
    if (name is! String ||
        name.trim().isEmpty ||
        streamUrl is! String ||
        streamUrl.trim().isEmpty) {
      return null;
    }
    final logoUrl = data['logoUrl'];
    final groupTitle = data['groupTitle'];
    return Channel(
      name: name.trim(),
      logoUrl: logoUrl is String && logoUrl.trim().isNotEmpty
          ? logoUrl.trim()
          : getDefaultLogoUrl(),
      streamUrl: streamUrl.trim(),
      groupTitle:
          groupTitle is String && groupTitle.trim().isNotEmpty
              ? groupTitle.trim()
              : '',
    );
  }

  Map<String, dynamic> _channelToJson(Channel channel) {
    return {
      'name': channel.name,
      'logoUrl': channel.logoUrl,
      'streamUrl': channel.streamUrl,
      'groupTitle': channel.groupTitle,
    };
  }

  Future<List<String>> _loadChannelNamesFromAsset(String path) async {
    final raw = await rootBundle.loadString(path);
    final data = loadYaml(raw);
    return _namesFromYaml(data);
  }

  List<String> _namesFromYaml(dynamic data) {
    final rawList = _extractChannelsList(data);
    if (rawList == null) {
      return [];
    }

    final names = <String>[];
    final seen = <String>{};
    for (final entry in rawList) {
      if (entry == null) {
        continue;
      }
      final name = entry.toString().trim();
      if (name.isEmpty) {
        continue;
      }
      final key = normalizeName(name);
      if (key.isEmpty || seen.contains(key)) {
        continue;
      }
      seen.add(key);
      names.add(name);
    }

    return names;
  }

  YamlList? _extractChannelsList(dynamic data) {
    if (data is YamlList) {
      return data;
    }
    if (data is YamlMap) {
      final raw = data['channels'];
      if (raw is YamlList) {
        return raw;
      }
    }
    return null;
  }

  Future<Map<String, Channel>> _fetchRemoteChannels() async {
    final cached = _remoteIndex;
    if (cached != null) {
      return cached;
    }
    final response = await http.get(Uri.parse(sourceUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to load M3U file');
    }
    final parsed = _parsePlaylist(response.body);
    final index = <String, Channel>{};
    for (final channel in parsed) {
      final key = normalizeName(channel.name);
      index.putIfAbsent(key, () => channel);
    }
    _remoteIndex = index;
    return index;
  }

  Future<List<Channel>> fetchRemoteChannels({bool forceRefresh = false}) async {
    if (!forceRefresh && _remoteChannels != null) {
      return _remoteChannels!;
    }
    if (forceRefresh) {
      _remoteIndex = null;
      _remoteChannels = null;
    }
    final index = await _fetchRemoteChannels();
    final channels = index.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _remoteChannels = channels;
    return channels;
  }

  List<Channel> _parsePlaylist(String text) {
    final result = <Channel>[];
    String? name;
    String logoUrl = getDefaultLogoUrl();
    String groupTitle = '';

    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      if (line.startsWith('#EXTINF:')) {
        name = extractChannelName(line);
        logoUrl = extractLogoUrl(line) ?? getDefaultLogoUrl();
        groupTitle = extractGroupTitle(line) ?? '';
        continue;
      }

      if (name == null) {
        continue;
      }

      result.add(Channel(
        name: name,
        logoUrl: logoUrl,
        streamUrl: line,
        groupTitle: groupTitle,
      ));
      name = null;
      logoUrl = getDefaultLogoUrl();
      groupTitle = '';
    }

    return result;
  }
}
