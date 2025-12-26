import '../entities/cast_connection_state.dart';
import '../entities/cast_device.dart';
import '../entities/cast_media_item.dart';

abstract class CastClientPort {
  Stream<List<CastDevice>> get devicesStream;
  Stream<CastConnectionState> get connectionStateStream;
  CastConnectionState get connectionState;

  Future<void> initialize();
  Future<void> startDiscovery();
  Future<void> stopDiscovery();
  Future<void> connect(CastDevice device);
  Future<void> disconnect();
  Future<void> loadMedia(CastMediaItem item);
}
