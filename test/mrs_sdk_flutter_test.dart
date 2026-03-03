import 'package:flutter_test/flutter_test.dart';

import 'package:mrs_sdk_flutter/mrs_sdk_flutter.dart';

void main() {
  group('SpokeZoneConfig', () {
    test('device mode constructor sets single auth mode', () {
      final config = SpokeZoneConfig.device(deviceAuth: _deviceCallbacks());

      expect(config.authMode, SpokeZoneAuthMode.device);
      expect(config.deviceAuth, isNotNull);
      expect(config.userAuth, isNull);
      expect(config.baseUri.toString(), 'https://api.spoke.zone');
    });

    test('user mode constructor sets single auth mode', () {
      final config = SpokeZoneConfig.user(userAuth: _userCallbacks());

      expect(config.authMode, SpokeZoneAuthMode.user);
      expect(config.userAuth, isNotNull);
      expect(config.deviceAuth, isNull);
      expect(config.baseUri.toString(), 'https://api.spoke.zone');
    });
  });
}

DeviceAuthCallbacks _deviceCallbacks() {
  return DeviceAuthCallbacks(
    cpuId: () async => 'cpu-1',
    uuid: () async => 'uuid-1',
    deviceId: () async => 'device-1',
    initialDeviceToken: () async => 'initial-device-token',
  );
}

UserAuthCallbacks _userCallbacks() {
  return UserAuthCallbacks(
    username: () async => 'user-a',
    password: () async => 'pw-a',
  );
}
