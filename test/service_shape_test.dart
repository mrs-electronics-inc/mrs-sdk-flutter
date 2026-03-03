import 'package:flutter_test/flutter_test.dart';
import 'package:mrs_sdk_flutter/mrs_sdk_flutter.dart';

import 'helpers.dart';

void main() {
  group('Service shape', () {
    test('SpokeZone exposes devices, dataFiles, and otaFiles namespaces', () {
      final zone = SpokeZone(
        config: SpokeZoneConfig.device(deviceAuth: deviceCallbacks()),
        httpClient: QueuedClient(),
      );

      expect(zone.devices, isA<DevicesClient>());
      expect(zone.dataFiles, isA<DataFilesClient>());
      expect(zone.otaFiles, isA<OtaFilesClient>());
    });

    test(
      'shared request pipeline injects auth header, retries, and maps errors',
      () async {
        final client = QueuedClient();
        client.enqueueJson(201, {'token': 'device-token'});
        client.enqueueJson(500, {'error': 'server'});
        client.enqueueJson(200, {
          'id': 9,
          'identifier': 'dev-9',
          'serialNumber': 'S-9',
          'modelId': 1,
          'name': 'Model A',
        });

        final zone = SpokeZone(
          config: SpokeZoneConfig.device(deviceAuth: deviceCallbacks()),
          httpClient: client,
        );

        await zone.devices.get(9);
        expect(client.requests[1].headers['x-access-token'], 'device-token');
        expect(client.requests[2].headers['x-access-token'], 'device-token');

        final forbiddenClient = QueuedClient();
        forbiddenClient.enqueueJson(201, {'token': 'device-token'});
        forbiddenClient.enqueueJson(403, {'message': 'forbidden'});

        final forbiddenZone = SpokeZone(
          config: SpokeZoneConfig.device(deviceAuth: deviceCallbacks()),
          httpClient: forbiddenClient,
        );

        await expectLater(
          forbiddenZone.devices.get(1),
          throwsA(
            isA<SpokeZoneException>().having(
              (e) => e.code,
              'code',
              SpokeZoneErrorCode.forbidden,
            ),
          ),
        );
      },
    );
  });
}
