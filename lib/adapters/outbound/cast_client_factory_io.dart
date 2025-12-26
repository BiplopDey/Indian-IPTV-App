import '../../domain/ports/cast_client_port.dart';
import 'google_cast_client.dart';

CastClientPort createCastClientImpl({
  required String appId,
}) {
  return GoogleCastClient(appId: appId);
}
