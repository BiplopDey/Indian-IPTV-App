import 'package:flutter_test/flutter_test.dart';

import 'package:ip_tv/adapters/outbound/cast_client_factory.dart';

void main() {
  test('createCastClient returns a client on supported platforms', () {
    final client = createCastClient(appId: 'CC1AD845');
    expect(client, isNotNull);
  });
}
