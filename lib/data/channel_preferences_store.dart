import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/channel.dart';

class ChannelPreferencesStore {
  Future<List<String>> loadOrder(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(key);
    if (stored == null || stored.isEmpty) {
      return [];
    }
    return stored;
  }

  Future<void> saveOrder(String key, List<String> names) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, names);
  }

  Future<List<Channel>> loadCustomChannels(
    String key, {
    required String defaultLogoUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
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
      final channel = _channelFromJson(
        entry,
        defaultLogoUrl: defaultLogoUrl,
      );
      if (channel != null) {
        result.add(channel);
      }
    }
    return result;
  }

  Future<void> saveCustomChannels(String key, List<Channel> channels) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
        channels.map((channel) => _channelToJson(channel)).toList());
    await prefs.setString(key, payload);
  }

  Channel? _channelFromJson(
    Map<String, dynamic> data, {
    required String defaultLogoUrl,
  }) {
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
          : defaultLogoUrl,
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
}
