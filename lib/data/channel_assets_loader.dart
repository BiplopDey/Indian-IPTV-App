import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

class ChannelAssetsLoader {
  Future<List<String>> loadNames(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return parseNames(raw);
  }

  List<String> parseNames(String raw) {
    final data = loadYaml(raw);
    final list = _extractChannelsList(data);
    if (list == null) {
      return [];
    }
    final result = <String>[];
    for (final entry in list) {
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
}
