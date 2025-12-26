import '../../domain/ports/cast_client_port.dart';
import 'web_cast_client.dart';

CastClientPort createCastClientImpl({
  required String appId,
}) {
  return WebCastClient(appId: appId);
}
