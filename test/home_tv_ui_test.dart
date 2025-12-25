import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ip_tv/config/app_config.dart';
import 'package:ip_tv/domain/entities/channel.dart';
import 'package:ip_tv/provider/channels_provider.dart';
import 'package:ip_tv/screens/home.dart';
import 'package:ip_tv/screens/home/tv_home_layout.dart';

class _FakeChannelsProvider extends ChannelsProvider {
  final List<Channel> seed;

  _FakeChannelsProvider(this.seed);

  @override
  Future<List<Channel>> fetchM3UFile() async {
    return seed;
  }

  @override
  List<Channel> filterChannels(String query) {
    return seed;
  }
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
    final provider = _FakeChannelsProvider(channels);

    await tester.pumpWidget(
      MaterialApp(
        home: Home(
          provider: provider,
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
}
