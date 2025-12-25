import 'package:flutter_test/flutter_test.dart';

import 'package:ip_tv/domain/entities/channel.dart';
import 'package:ip_tv/screens/home/app_version_loader.dart';
import 'package:ip_tv/screens/home/home_channels_service.dart';
import 'package:ip_tv/screens/home/home_controller.dart';

class _RecordingService implements HomeChannelsService {
  _RecordingService(this.seed);

  final List<Channel> seed;
  final List<List<Channel>> savedOrders = [];
  final List<String> removedNames = [];

  @override
  Future<List<Channel>> fetchChannels() async => seed;

  @override
  Future<List<Channel>> fetchRemoteChannels({bool forceRefresh = false}) async {
    return seed;
  }

  @override
  Future<void> saveChannelOrder(List<Channel> ordered) async {
    savedOrders.add(List<Channel>.from(ordered));
  }

  @override
  Future<void> removeCustomChannelByName(String name) async {
    removedNames.add(name);
  }

  @override
  String normalizeName(String value) => value.toLowerCase();
}

class _FakeVersionLoader implements AppVersionLoader {
  _FakeVersionLoader(this.version);

  final String? version;

  @override
  Future<String?> loadAppVersion() async => version;
}

void main() {
  test('initialize loads channels and sets version', () async {
    final channels = [
      Channel(
        name: 'Alpha TV',
        logoUrl: '',
        streamUrl: 'http://example.com/alpha.m3u8',
        groupTitle: '',
      ),
    ];
    final service = _RecordingService(channels);
    final controller = HomeController(
      channelsService: service,
      versionLoader: _FakeVersionLoader('2.2.0+13'),
      autoLaunchPlayer: false,
    );

    await controller.initialize();

    expect(controller.state.channels.length, 1);
    expect(controller.state.appVersion, '2.2.0+13');
    expect(controller.state.isLaunchingPlayer, isFalse);
    expect(controller.state.pendingLaunchIndex, isNull);
  });

  test('auto launch sets pending index when enabled', () async {
    final channels = [
      Channel(
        name: 'Alpha TV',
        logoUrl: '',
        streamUrl: 'http://example.com/alpha.m3u8',
        groupTitle: '',
      ),
    ];
    final service = _RecordingService(channels);
    final controller = HomeController(
      channelsService: service,
      versionLoader: _FakeVersionLoader(null),
      autoLaunchPlayer: true,
    );

    await controller.initialize();

    expect(controller.state.isLaunchingPlayer, isTrue);
    expect(controller.state.pendingLaunchIndex, 0);

    controller.markLaunchHandled();
    expect(controller.state.isLaunchingPlayer, isFalse);
    expect(controller.state.pendingLaunchIndex, isNull);
  });

  test('search query filters after debounce', () async {
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
    final service = _RecordingService(channels);
    final controller = HomeController(
      channelsService: service,
      versionLoader: _FakeVersionLoader(null),
      autoLaunchPlayer: false,
    );

    await controller.initialize();
    controller.setSearchQuery('beta');
    await Future<void>.delayed(const Duration(milliseconds: 600));

    expect(controller.state.filteredChannels.length, 1);
    expect(controller.state.filteredChannels.first.name, 'Beta TV');
  });

  test('moveChannel updates order and saves', () async {
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
    final service = _RecordingService(channels);
    final controller = HomeController(
      channelsService: service,
      versionLoader: _FakeVersionLoader(null),
      autoLaunchPlayer: false,
    );

    await controller.initialize();
    await controller.moveChannel(0, 1);

    expect(controller.state.channels.first.name, 'Beta TV');
    expect(service.savedOrders, isNotEmpty);
  });
}
