import 'dart:convert';

import '../model/channel.dart';

class PlaylistParser {
  List<Channel> parse(String text, {required String defaultLogoUrl}) {
    final result = <Channel>[];
    String? name;
    String logoUrl = defaultLogoUrl;
    String groupTitle = '';

    for (final rawLine in const LineSplitter().convert(text)) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      if (line.startsWith('#EXTINF:')) {
        name = extractChannelName(line);
        logoUrl = extractLogoUrl(line) ?? defaultLogoUrl;
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
      logoUrl = defaultLogoUrl;
      groupTitle = '';
    }

    return result;
  }

  String? extractChannelName(String line) {
    final parts = line.split(',');
    return parts.isEmpty ? null : parts.last;
  }

  String? extractLogoUrl(String line) {
    final parts = line.split('"');
    if (parts.length > 1 && isValidUrl(parts[1])) {
      return parts[1];
    }
    if (parts.length > 5 && isValidUrl(parts[5])) {
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
}
