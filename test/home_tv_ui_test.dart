import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ip_tv/config/app_config.dart';
import 'package:ip_tv/domain/entities/channel.dart';
import 'package:ip_tv/screens/home.dart';
import 'package:ip_tv/screens/home/app_version_loader.dart';
import 'package:ip_tv/screens/home/home_channels_service.dart';
import 'package:ip_tv/screens/home/tv/tv_dialogs.dart';
import 'package:ip_tv/screens/home/tv/tv_home_layout.dart';

class _FakeChannelsService implements HomeChannelsService {
  _FakeChannelsService(this.seed);

  final List<Channel> seed;

  @override
  Future<List<Channel>> fetchChannels() async => seed;

  @override
  Future<List<Channel>> fetchRemoteChannels({bool forceRefresh = false}) async {
    return seed;
  }

  @override
  Future<void> saveChannelOrder(List<Channel> ordered) async {}

  @override
  Future<void> removeCustomChannelByName(String name) async {}

  @override
  String normalizeName(String value) => value.toLowerCase();
}

class _FakeVersionLoader implements AppVersionLoader {
  @override
  Future<String?> loadAppVersion() async => null;
}

class _SlowChannelsService implements HomeChannelsService {
  _SlowChannelsService(this._completer);

  final Completer<List<Channel>> _completer;

  @override
  Future<List<Channel>> fetchChannels() => _completer.future;

  @override
  Future<List<Channel>> fetchRemoteChannels({bool forceRefresh = false}) async {
    return const [];
  }

  @override
  Future<void> saveChannelOrder(List<Channel> ordered) async {}

  @override
  Future<void> removeCustomChannelByName(String name) async {}

  @override
  String normalizeName(String value) => value.toLowerCase();
}

void main() {
  setUp(() {
    AppConfig.setTargetForTests('tv');
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDown(() {
    AppConfig.clearTargetOverride();
  });

  testWidgets('Home renders TV layout without search field',
      (WidgetTester tester) async {
    final view = tester.view;
    view.physicalSize = const Size(1920, 1080);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    final channels = [
      Channel(
        name: 'Alpha TV',
        logoUrl: '',
        streamUrl: 'http://example.com/alpha.m3u8',
        groupTitle: 'News',
      ),
      Channel(
        name: 'Beta TV',
        logoUrl: '',
        streamUrl: 'http://example.com/beta.m3u8',
        groupTitle: '',
      ),
    ];
    final service = _FakeChannelsService(channels);

    await tester.pumpWidget(
      MaterialApp(
        home: Home(
          channelsService: service,
          versionLoader: _FakeVersionLoader(),
          autoLaunchPlayer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Live TV'), findsOneWidget);
    expect(find.text('Add Channels'), findsOneWidget);
    expect(find.text('Manage Channels'), findsOneWidget);
    expect(find.text('All Channels'), findsOneWidget);
    expect(find.text('Live Now'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Alpha TV'), findsWidgets);
    expect(find.text('Flavor: tv'), findsOneWidget);
  });

  testWidgets('Home renders compact TV layout on narrow screens',
      (WidgetTester tester) async {
    final view = tester.view;
    view.physicalSize = const Size(960, 720);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    final channels = [
      Channel(
        name: 'Alpha TV',
        logoUrl: '',
        streamUrl: 'http://example.com/alpha.m3u8',
        groupTitle: 'News',
      ),
    ];
    final service = _FakeChannelsService(channels);

    await tester.pumpWidget(
      MaterialApp(
        home: Home(
          channelsService: service,
          versionLoader: _FakeVersionLoader(),
          autoLaunchPlayer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Live TV'), findsOneWidget);
    expect(find.text('Add Channels'), findsOneWidget);
    expect(find.text('All Channels'), findsOneWidget);
  });

  testWidgets('TvHomeLayout shows loading card when empty and loading',
      (WidgetTester tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeLayout(
          channels: const [],
          isLoading: true,
          version: '2.1.9+12',
          flavor: 'tv',
          onManageChannels: null,
          onChannelSelected: (_) {},
          scrollController: controller,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Loading channels...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Home shows TV loading card while channels load',
      (WidgetTester tester) async {
    final completer = Completer<List<Channel>>();
    final service = _SlowChannelsService(completer);

    await tester.pumpWidget(
      MaterialApp(
        home: Home(
          channelsService: service,
          versionLoader: _FakeVersionLoader(),
          autoLaunchPlayer: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Loading channels...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('TV add channels dialog avoids overflow on small screens',
      (WidgetTester tester) async {
    final errors = <FlutterErrorDetails>[];
    final previousHandler = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details);

    final view = tester.view;
    view.physicalSize = const Size(960, 540);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    final channels = [
      Channel(
        name: 'Alpha TV',
        logoUrl: '',
        streamUrl: 'http://example.com/alpha.m3u8',
        groupTitle: '',
      ),
      Channel(
        name: 'Beta TV',
        logoUrl: '',
        streamUrl: 'http://example.com/beta.m3u8',
        groupTitle: '',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showTvAddChannelsDialog(
                context: context,
                remoteChannels: Future.value(channels),
                existingChannels: const [],
                normalizeName: (value) => value.toLowerCase(),
              );
            });
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    FlutterError.onError = previousHandler;
    expect(errors, isEmpty);
  });

  testWidgets('TV add channels dialog closes cleanly after selection',
      (WidgetTester tester) async {
    final errors = <FlutterErrorDetails>[];
    final previousHandler = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details);

    final channels = [
      Channel(
        name: 'Alpha TV',
        logoUrl: '',
        streamUrl: 'http://example.com/alpha.m3u8',
        groupTitle: '',
      ),
      Channel(
        name: 'Beta TV',
        logoUrl: '',
        streamUrl: 'http://example.com/beta.m3u8',
        groupTitle: '',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showTvAddChannelsDialog(
                context: context,
                remoteChannels: Future.value(channels),
                existingChannels: const [],
                normalizeName: (value) => value.toLowerCase(),
              );
            });
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Alpha TV'));
    await tester.pump();
    await tester.tap(find.text('Add (1)'));
    await tester.pumpAndSettle();

    FlutterError.onError = previousHandler;
    expect(errors, isEmpty);
  });

  testWidgets('TV manage channels dialog avoids overflow on small screens',
      (WidgetTester tester) async {
    final errors = <FlutterErrorDetails>[];
    final previousHandler = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details);

    final view = tester.view;
    view.physicalSize = const Size(960, 540);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    final channels = List.generate(
      8,
      (index) => Channel(
        name: 'Channel $index',
        logoUrl: '',
        streamUrl: 'http://example.com/$index.m3u8',
        groupTitle: 'Group',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showTvManageChannelsDialog(
                context: context,
                channels: channels,
                onMove: (_, __) async {},
                onRemove: (_) async {},
              );
            });
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    FlutterError.onError = previousHandler;
    expect(errors, isEmpty);
  });
}
