import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

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

  group('Auth providers', () {
    test('DeviceAuth.login sends expected request and handles 200/201', () async {
      final client = _QueuedClient();
      client.enqueueJson(200, {'status': 'ok'});

      final auth200 = DeviceAuth(
        baseUri: Uri.parse('https://api.spoke.zone'),
        callbacks: _deviceCallbacks(),
        httpClient: client,
      );

      final token200 = await auth200.login();
      expect(token200, 'initial-device-token');
      final request200 = client.requests.single as http.Request;
      expect(request200.method, 'POST');
      expect(request200.url.path, '/loginDevice');
      final body200 = jsonDecode(request200.body) as Map<String, dynamic>;
      expect(body200['token'], 'initial-device-token');
      expect(body200['cpu_id'], 'cpu-1');
      expect(body200['uuid'], 'uuid-1');

      final renewedClient = _QueuedClient();
      renewedClient.enqueueJson(201, {'token': 'renewed-token'});
      final auth201 = DeviceAuth(
        baseUri: Uri.parse('https://api.spoke.zone'),
        callbacks: _deviceCallbacks(),
        httpClient: renewedClient,
      );

      expect(await auth201.login(), 'renewed-token');
    });

    test('DeviceAuth.login maps terminal errors', () async {
      final client = _QueuedClient();
      client.enqueueJson(403, {'message': 'forbidden'});
      final auth = DeviceAuth(
        baseUri: Uri.parse('https://api.spoke.zone'),
        callbacks: _deviceCallbacks(),
        httpClient: client,
      );

      await expectLater(
        auth.login(),
        throwsA(
          isA<SpokeZoneException>().having(
            (e) => e.code,
            'code',
            SpokeZoneErrorCode.forbidden,
          ),
        ),
      );
    });

    test('UserAuth.login uses username/password callbacks and token lifecycle entry points', () async {
      final client = _QueuedClient();
      client.enqueueJson(200, {
        'token': 'user-token',
        'expires': 1,
        'user': {'username': 'u'},
      });

      final auth = UserAuth(
        baseUri: Uri.parse('https://api.spoke.zone'),
        callbacks: _userCallbacks(),
        httpClient: client,
      );

      final token = await auth.login();
      expect(token, 'user-token');

      final request = client.requests.single as http.Request;
      expect(request.url.path, '/login');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body, {'username': 'user-a', 'password': 'pw-a'});

      expect(await auth.getAccessToken(), 'user-token');
      expect(client.requests, hasLength(1));
    });

    test('UserAuth.login applies retry parity and failure mapping', () async {
      final client = _QueuedClient();
      client.enqueueJson(500, {'error': 'server'});
      client.enqueueJson(429, {'error': 'rate'});
      client.enqueueJson(200, {
        'token': 'ok-token',
        'expires': 1,
        'user': {'username': 'u'},
      });

      final auth = UserAuth(
        baseUri: Uri.parse('https://api.spoke.zone'),
        callbacks: _userCallbacks(),
        httpClient: client,
      );

      expect(await auth.login(), 'ok-token');
      expect(client.requests, hasLength(3));

      final terminalClient = _QueuedClient();
      terminalClient.enqueueJson(403, {'error': 'forbidden'});
      final terminal = UserAuth(
        baseUri: Uri.parse('https://api.spoke.zone'),
        callbacks: _userCallbacks(),
        httpClient: terminalClient,
      );

      await expectLater(
        terminal.login(),
        throwsA(
          isA<SpokeZoneException>().having(
            (e) => e.code,
            'code',
            SpokeZoneErrorCode.forbidden,
          ),
        ),
      );
    });
  });

  group('Service shape', () {
    test('SpokeZone exposes devices, dataFiles, and otaFiles namespaces', () {
      final zone = SpokeZone(
        config: SpokeZoneConfig.device(deviceAuth: _deviceCallbacks()),
        httpClient: _QueuedClient(),
      );

      expect(zone.devices, isA<DevicesClient>());
      expect(zone.dataFiles, isA<DataFilesClient>());
      expect(zone.otaFiles, isA<OtaFilesClient>());
    });

    test('shared request pipeline injects auth header, retries, and maps errors', () async {
      final client = _QueuedClient();
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
        config: SpokeZoneConfig.device(deviceAuth: _deviceCallbacks()),
        httpClient: client,
      );

      await zone.devices.get(9);
      expect(client.requests[1].headers['x-access-token'], 'device-token');
      expect(client.requests[2].headers['x-access-token'], 'device-token');

      final forbiddenClient = _QueuedClient();
      forbiddenClient.enqueueJson(201, {'token': 'device-token'});
      forbiddenClient.enqueueJson(403, {'message': 'forbidden'});

      final forbiddenZone = SpokeZone(
        config: SpokeZoneConfig.device(deviceAuth: _deviceCallbacks()),
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
    });
  });

  group('Endpoint behavior', () {
    test('devices.get maps fields and defaults optional values', () async {
      final client = _QueuedClient();
      client.enqueueJson(201, {'token': 'device-token'});
      client.enqueueJson(200, {
        'id': 8,
        'identifier': 'd-8',
        'serialNumber': 'SN-8',
        'modelId': 9,
        'name': 'Model Nine',
        'lastOnline': 'not-a-date',
      });

      final zone = SpokeZone(
        config: SpokeZoneConfig.device(deviceAuth: _deviceCallbacks()),
        httpClient: client,
      );

      final device = await zone.devices.get(8);
      expect(device.modelName, 'Model Nine');
      expect(device.lastOnline, isNull);
      expect(device.lastLocation, isNull);
      expect(device.softwareVersions, isEmpty);
    });

    test('devices.get maps shared Coordinates when both coordinates are present', () async {
      final client = _QueuedClient();
      client.enqueueJson(201, {'token': 'device-token'});
      client.enqueueJson(200, {
        'id': 1,
        'identifier': 'd-1',
        'serialNumber': 'SN-1',
        'modelId': 2,
        'name': 'Model One',
        'lastLatitude': 41.1,
        'lastLongitude': -71.2,
      });

      final zone = SpokeZone(
        config: SpokeZoneConfig.device(deviceAuth: _deviceCallbacks()),
        httpClient: client,
      );

      final device = await zone.devices.get(1);
      expect(device.lastLocation, isA<Coordinates>());
      expect(device.lastLocation!.latitude, 41.1);
      expect(device.lastLocation!.longitude, -71.2);
    });

    test('dataFiles.create validates type and extracts id', () async {
      final client = _QueuedClient();
      client.enqueueJson(201, {'token': 'device-token'});
      client.enqueueJson(200, {'id': 99});

      final zone = SpokeZone(
        config: SpokeZoneConfig.device(deviceAuth: _deviceCallbacks()),
        httpClient: client,
      );

      final id = await zone.dataFiles.create('log');
      expect(id, 99);

      final request = client.requests[1] as http.Request;
      expect(request.url.path, '/api/v2/data-files');
      expect(jsonDecode(request.body), {'type': 'log'});
    });

    test('dataFiles.upload sends multipart bytes in files field', () async {
      final client = _QueuedClient();
      client.enqueueJson(201, {'token': 'device-token'});
      client.enqueueJson(200, {'ok': true});

      final zone = SpokeZone(
        config: SpokeZoneConfig.device(deviceAuth: _deviceCallbacks()),
        httpClient: client,
      );

      await zone.dataFiles.upload(7, Uint8List.fromList([1, 2, 3]));

      final request = client.requests[1] as http.MultipartRequest;
      expect(request.url.path, '/api/v2/data-files/7/file');
      expect(request.files.single.field, 'files');
      expect(request.files.single.length, 3);
    });

    test('otaFiles.list applies default query parameters and maps items', () async {
      final client = _QueuedClient();
      client.enqueueJson(200, {
        'token': 'user-token',
        'expires': 1,
        'user': {'username': 'u'},
      });
      client.enqueueJson(200, [
        {
          'id': 1,
          'modelId': 2,
          'moduleId': 3,
          'module': 'ECU',
          'version': '1.2.3',
          'fileLocation': '/bin',
          'isActive': true,
          'createdDate': '2026-01-01',
          'releaseNotes': 'notes',
        },
      ]);

      final zone = SpokeZone(
        config: SpokeZoneConfig.user(userAuth: _userCallbacks()),
        httpClient: client,
      );

      final list = await zone.otaFiles.list();
      expect(list.single.module, 'ECU');

      final request = client.requests[1] as http.Request;
      expect(request.url.queryParameters['limit'], '50');
      expect(request.url.queryParameters['offset'], '0');
    });

    test('otaFiles.list forwards caller query options', () async {
      final client = _QueuedClient();
      client.enqueueJson(200, {
        'token': 'user-token',
        'expires': 1,
        'user': {'username': 'u'},
      });
      client.enqueueJson(200, []);

      final zone = SpokeZone(
        config: SpokeZoneConfig.user(userAuth: _userCallbacks()),
        httpClient: client,
      );

      await zone.otaFiles.list(
        options: const OtaFilesListOptions(
          searchTerm: 'abc',
          searchFields: 'module,version',
          sort: 'createdDate',
          sortOrder: 'desc',
          limit: 25,
          offset: 10,
        ),
      );

      final request = client.requests[1] as http.Request;
      expect(request.url.queryParameters['searchTerm'], 'abc');
      expect(request.url.queryParameters['searchFields'], 'module,version');
      expect(request.url.queryParameters['sort'], 'createdDate');
      expect(request.url.queryParameters['sortOrder'], 'desc');
      expect(request.url.queryParameters['limit'], '25');
      expect(request.url.queryParameters['offset'], '10');
    });

    test('otaFiles.download returns binary bytes', () async {
      final client = _QueuedClient();
      client.enqueueJson(200, {
        'token': 'user-token',
        'expires': 1,
        'user': {'username': 'u'},
      });
      client.enqueueBytes(200, [5, 4, 3]);

      final zone = SpokeZone(
        config: SpokeZoneConfig.user(userAuth: _userCallbacks()),
        httpClient: client,
      );

      final bytes = await zone.otaFiles.download(4);
      expect(bytes, Uint8List.fromList([5, 4, 3]));
    });
  });

  group('Reliability and errors', () {
    test('retries transport errors + 429 + 5xx using 15s -> 30s -> 60s delays', () async {
      final delays = <Duration>[];
      final client = _QueuedClient();
      client.enqueueException(http.ClientException('network'));
      client.enqueueJson(429, {'error': 'rate'});
      client.enqueueJson(500, {'error': 'server'});
      client.enqueueJson(201, {'token': 'device-token'});
      client.enqueueJson(200, {
        'id': 2,
        'identifier': 'd2',
        'serialNumber': 's2',
        'modelId': 2,
        'name': 'm2',
      });

      final zone = SpokeZone(
        config: SpokeZoneConfig.device(deviceAuth: _deviceCallbacks()),
        httpClient: client,
        delay: (duration) async => delays.add(duration),
      );

      await zone.devices.get(2);
      expect(delays, [
        const Duration(seconds: 15),
        const Duration(seconds: 30),
        const Duration(seconds: 60),
      ]);
    });

    test('does not retry non-429 4xx responses', () async {
      final client = _QueuedClient();
      client.enqueueJson(401, {'error': 'unauthorized'});

      final auth = DeviceAuth(
        baseUri: Uri.parse('https://api.spoke.zone'),
        callbacks: _deviceCallbacks(),
        httpClient: client,
      );

      await expectLater(
        auth.login(),
        throwsA(
          isA<SpokeZoneException>().having(
            (e) => e.code,
            'code',
            SpokeZoneErrorCode.unauthorized,
          ),
        ),
      );
      expect(client.requests, hasLength(1));
    });

    test('backoff abstraction supports default and custom strategy behavior', () async {
      final defaults = FixedDelayBackoffStrategy();
      expect(defaults.delayForRetry(1), const Duration(seconds: 15));
      expect(defaults.delayForRetry(2), const Duration(seconds: 30));
      expect(defaults.delayForRetry(3), const Duration(seconds: 60));
      expect(defaults.delayForRetry(4), isNull);

      final called = <int>[];
      final custom = _TestBackoffStrategy((retryNumber) {
        called.add(retryNumber);
        return retryNumber == 1 ? Duration.zero : null;
      });

      final client = _QueuedClient();
      client.enqueueJson(500, {'error': 'server'});
      client.enqueueJson(201, {'token': 'token'});

      final auth = DeviceAuth(
        baseUri: Uri.parse('https://api.spoke.zone'),
        callbacks: _deviceCallbacks(),
        httpClient: client,
        backoffStrategy: custom,
        delay: (_) async {},
      );

      expect(await auth.login(), 'token');
      expect(called, [1]);
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

  void enqueueBytes(int statusCode, List<int> bytes) {
    _handlers.add(
      (_) async => http.StreamedResponse(
        Stream<List<int>>.fromIterable(<List<int>>[bytes]),
        statusCode,
      ),
    );
  }

  void enqueueException(Object error) {
    _handlers.add((_) async => throw error);
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

class _TestBackoffStrategy implements BackoffStrategy {
  _TestBackoffStrategy(this._builder);

  final Duration? Function(int retryNumber) _builder;

  @override
  Duration? delayForRetry(int retryNumber) => _builder(retryNumber);
}
