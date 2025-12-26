import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:ip_tv/application/cast_session_service.dart';
import 'package:ip_tv/domain/entities/cast_connection_state.dart';
import 'package:ip_tv/domain/entities/cast_device.dart';
import 'package:ip_tv/domain/entities/cast_media_item.dart';
import 'package:ip_tv/domain/ports/cast_client_port.dart';

class FakeCastClient implements CastClientPort {
  final StreamController<List<CastDevice>> devicesController =
      StreamController<List<CastDevice>>.broadcast();
  final StreamController<CastConnectionState> stateController =
      StreamController<CastConnectionState>.broadcast();
  final List<String> calls = [];

  int initializeCount = 0;
  CastConnectionState _state = CastConnectionState.disconnected;

  @override
  Stream<List<CastDevice>> get devicesStream => devicesController.stream;

  @override
  Stream<CastConnectionState> get connectionStateStream =>
      stateController.stream;

  @override
  CastConnectionState get connectionState => _state;

  @override
  Future<void> initialize() async {
    initializeCount += 1;
    calls.add('initialize');
  }

  @override
  Future<void> startDiscovery() async {
    calls.add('startDiscovery');
  }

  @override
  Future<void> stopDiscovery() async {
    calls.add('stopDiscovery');
  }

  @override
  Future<void> connect(CastDevice device) async {
    calls.add('connect:${device.id}');
    _state = CastConnectionState.connected;
    stateController.add(_state);
  }

  @override
  Future<void> disconnect() async {
    calls.add('disconnect');
    _state = CastConnectionState.disconnected;
    stateController.add(_state);
  }

  @override
  Future<void> loadMedia(CastMediaItem item) async {
    calls.add('load:${item.streamUrl}');
  }

  Future<void> close() async {
    await devicesController.close();
    await stateController.close();
  }
}

void main() {
  test('initialize only runs once', () async {
    final client = FakeCastClient();
    addTearDown(client.close);
    final service = CastSessionService(client: client);

    await service.initialize();
    await service.initialize();

    expect(client.initializeCount, 1);
  });

  test('connectAndCast connects before loading media', () async {
    final client = FakeCastClient();
    addTearDown(client.close);
    final service = CastSessionService(client: client);

    await service.connectAndCast(
      device: const CastDevice(id: 'device-1', name: 'Living Room TV'),
      media: CastMediaItem(
        streamUrl: Uri.parse('https://example.com/live.m3u8'),
        title: 'Live',
      ),
    );

    expect(
      client.calls,
      ['connect:device-1', 'load:https://example.com/live.m3u8'],
    );
  });

  test('castMedia forwards to loadMedia', () async {
    final client = FakeCastClient();
    addTearDown(client.close);
    final service = CastSessionService(client: client);

    await service.castMedia(
      CastMediaItem(
        streamUrl: Uri.parse('https://example.com/stream.m3u8'),
        title: 'Channel',
      ),
    );

    expect(client.calls, ['load:https://example.com/stream.m3u8']);
  });
}
