import '../domain/entities/cast_connection_state.dart';
import '../domain/entities/cast_device.dart';
import '../domain/entities/cast_media_item.dart';
import '../domain/ports/cast_client_port.dart';

class CastSessionService {
  CastSessionService({
    required CastClientPort client,
  }) : _client = client;

  final CastClientPort _client;
  bool _initialized = false;

  Stream<List<CastDevice>> get devicesStream => _client.devicesStream;
  Stream<CastConnectionState> get connectionStateStream =>
      _client.connectionStateStream;
  CastConnectionState get connectionState => _client.connectionState;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    await _client.initialize();
  }

  Future<void> startDiscovery() => _client.startDiscovery();

  Future<void> stopDiscovery() => _client.stopDiscovery();

  Future<void> connectAndCast({
    required CastDevice device,
    required CastMediaItem media,
  }) async {
    await _client.connect(device);
    await _client.loadMedia(media);
  }

  Future<void> castMedia(CastMediaItem media) {
    return _client.loadMedia(media);
  }

  Future<void> disconnect() => _client.disconnect();
}
