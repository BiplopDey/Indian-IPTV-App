import '../../domain/ports/cast_client_port.dart';
import 'cast_client_factory_stub.dart'
    if (dart.library.html) 'cast_client_factory_web.dart'
    if (dart.library.io) 'cast_client_factory_io.dart';

CastClientPort? createCastClient({
  required String appId,
}) {
  return createCastClientImpl(appId: appId);
}
