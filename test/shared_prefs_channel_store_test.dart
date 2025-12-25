import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ip_tv/adapters/outbound/shared_prefs_channel_store.dart';
import 'package:ip_tv/domain/entities/channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPrefsChannelStore', () {
    const orderKey = 'order_key';
    const customKey = 'custom_key';
    const defaultLogo = 'assets/images/tv-icon.png';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loadOrder returns empty when no value stored', () async {
      final store = SharedPrefsChannelStore();
      final result = await store.loadOrder(orderKey);
      expect(result, isEmpty);
    });

    test('saveOrder persists names', () async {
      final store = SharedPrefsChannelStore();
      await store.saveOrder(orderKey, ['One', 'Two']);
      final result = await store.loadOrder(orderKey);
      expect(result, ['One', 'Two']);
    });

    test('loadCustomChannels skips invalid entries and applies defaults',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        customKey,
        jsonEncode([
          {
            'name': 'Valid',
            'streamUrl': 'https://example.com/ok.m3u8',
            'logoUrl': '',
            'groupTitle': 'News'
          },
          {'name': '', 'streamUrl': 'https://example.com/bad.m3u8'},
          {'name': 'MissingStream'},
        ]),
      );

      final store = SharedPrefsChannelStore();
      final result = await store.loadCustomChannels(
        customKey,
        defaultLogoUrl: defaultLogo,
      );

      expect(result.length, 1);
      expect(result.first.name, 'Valid');
      expect(result.first.logoUrl, defaultLogo);
      expect(result.first.groupTitle, 'News');
    });

    test('saveCustomChannels roundtrips data', () async {
      final store = SharedPrefsChannelStore();
      final channels = [
        Channel(
          name: 'Stored',
          logoUrl: 'logo',
          streamUrl: 'https://example.com/stream.m3u8',
          groupTitle: 'Group',
        ),
      ];

      await store.saveCustomChannels(customKey, channels);
      final result = await store.loadCustomChannels(
        customKey,
        defaultLogoUrl: defaultLogo,
      );

      expect(result.length, 1);
      expect(result.first.name, 'Stored');
      expect(result.first.groupTitle, 'Group');
    });
  });
}
