import 'dart:collection';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

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

    test('device and user modes both decorate requests with x-access-token', () async {
      final deviceClient = _QueuedClient();
      deviceClient.enqueueJson(201, {'token': 'device-renewed'});
      deviceClient.enqueueJson(200, {
        'id': 22,
        'identifier': 'dev-a',
        'serialNumber': 'S-1',
        'modelId': 3,
        'name': 'Model Z',
      });

      final deviceZone = SpokeZone(
        config: SpokeZoneConfig.device(deviceAuth: _deviceCallbacks()),
        httpClient: deviceClient,
      );
      await deviceZone.devices.get(22);

      expect(deviceClient.requests[1].headers['x-access-token'], 'device-renewed');

      final userClient = _QueuedClient();
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
        config: SpokeZoneConfig.user(userAuth: _userCallbacks()),
        httpClient: userClient,
      );
      await userZone.otaFiles.list();

      expect(userClient.requests[1].headers['x-access-token'], 'user-token');
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

class _QueuedClient extends http.BaseClient {
  final Queue<Future<http.StreamedResponse> Function(http.BaseRequest)> _handlers =
      Queue<Future<http.StreamedResponse> Function(http.BaseRequest)>();
  final List<http.BaseRequest> requests = <http.BaseRequest>[];

  void enqueueJson(int statusCode, Object body) {
    _handlers.add((_) async {
      final encoded = utf8.encode(jsonEncode(body));
      return http.StreamedResponse(
        Stream<List<int>>.fromIterable(<List<int>>[encoded]),
        statusCode,
        headers: const {'content-type': 'application/json'},
      );
    });
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    if (_handlers.isEmpty) {
      throw StateError('No queued response for ${request.method} ${request.url}');
    }
    final handler = _handlers.removeFirst();
    return handler(request);
  }
}
