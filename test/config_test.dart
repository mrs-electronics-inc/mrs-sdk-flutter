import 'package:flutter_test/flutter_test.dart';
import 'package:mrs_sdk_flutter/mrs_sdk_flutter.dart';

import 'helpers.dart';

void main() {
  group('SpokeZoneConfig', () {
    test('device mode constructor sets single auth mode', () {
      final config = SpokeZoneConfig.device(deviceAuth: deviceCallbacks());

      expect(config.authMode, SpokeZoneAuthMode.device);
      expect(config.deviceAuth, isNotNull);
      expect(config.userAuth, isNull);
      expect(config.baseUri.toString(), 'https://api.spoke.zone');
    });

    test('user mode constructor sets single auth mode', () {
      final config = SpokeZoneConfig.user(userAuth: userCallbacks());

      expect(config.authMode, SpokeZoneAuthMode.user);
      expect(config.userAuth, isNotNull);
      expect(config.deviceAuth, isNull);
      expect(config.baseUri.toString(), 'https://api.spoke.zone');
    });

    test('device and user modes both decorate requests with x-access-token', () async {
      final deviceClient = QueuedClient();
      deviceClient.enqueueJson(201, {'token': 'device-renewed'});
      deviceClient.enqueueJson(200, {
        'id': 22,
        'identifier': 'dev-a',
        'serialNumber': 'S-1',
        'modelId': 3,
        'name': 'Model Z',
      });

      final deviceZone = SpokeZone(
        config: SpokeZoneConfig.device(deviceAuth: deviceCallbacks()),
        httpClient: deviceClient,
      );
      await deviceZone.devices.get(22);

      expect(deviceClient.requests[1].headers['x-access-token'], 'device-renewed');

      final userClient = QueuedClient();
      userClient.enqueueJson(200, {
        'token': 'user-token',
        'expires': 123,
        'user': {'username': 'user'},
      });
      userClient.enqueueJson(200, [
        {
          'id': 1,
          'modelId': 10,
          'moduleId': 11,
          'module': 'm',
          'version': '1.0.0',
          'fileLocation': '/ota',
          'isActive': true,
          'createdDate': '2026-01-01',
          'releaseNotes': 'notes',
        },
      ]);

      final userZone = SpokeZone(
        config: SpokeZoneConfig.user(userAuth: userCallbacks()),
        httpClient: userClient,
      );
      await userZone.otaFiles.list();

      expect(userClient.requests[1].headers['x-access-token'], 'user-token');
    });
  });
}
