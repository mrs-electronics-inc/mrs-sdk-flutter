import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mrs_sdk_flutter/mrs_sdk_flutter.dart';

import 'helpers.dart';

void main() {
  group('Endpoint behavior', () {
    test('devices.get maps fields and defaults optional values', () async {
      final client = QueuedClient();
      client.enqueueJson(201, {'token': 'device-token'});
      client.enqueueJson(200, {
        'id': 8,
        'identifier': 'd-8',
        'serialNumber': 'SN-8',
        'modelId': 9,
        'name': 'Model Nine',
        'lastOnline': 'not-a-date',
      });

      final spokeZone = SpokeZone(
        config: SpokeZoneConfig.device(deviceAuth: deviceCallbacks()),
        httpClient: client,
      );

      final device = await spokeZone.devices.get(8);
      expect(device.modelName, 'Model Nine');
      expect(device.lastOnline, isNull);
      expect(device.lastLocation, isNull);
      expect(device.softwareVersions, isEmpty);
    });

    test(
      'devices.get maps shared Coordinates when both coordinates are present',
      () async {
        final client = QueuedClient();
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

        final spokeZone = SpokeZone(
          config: SpokeZoneConfig.device(deviceAuth: deviceCallbacks()),
          httpClient: client,
        );

        final device = await spokeZone.devices.get(1);
        expect(device.lastLocation, isA<Coordinates>());
        expect(device.lastLocation!.latitude, 41.1);
        expect(device.lastLocation!.longitude, -71.2);
      },
    );

    test('dataFiles.create validates type and extracts id', () async {
      final client = QueuedClient();
      client.enqueueJson(201, {'token': 'device-token'});
      client.enqueueJson(200, {'id': 99});

      final spokeZone = SpokeZone(
        config: SpokeZoneConfig.device(deviceAuth: deviceCallbacks()),
        httpClient: client,
      );

      final id = await spokeZone.dataFiles.create('log');
      expect(id, 99);

      final request = client.requests[1] as http.Request;
      expect(request.url.path, '/api/v2/data-files');
      expect(jsonDecode(request.body), {'type': 'log'});
    });

    test('dataFiles.upload sends multipart bytes in files field', () async {
      final client = QueuedClient();
      client.enqueueJson(201, {'token': 'device-token'});
      client.enqueueJson(200, {'ok': true});

      final spokeZone = SpokeZone(
        config: SpokeZoneConfig.device(deviceAuth: deviceCallbacks()),
        httpClient: client,
      );

      await spokeZone.dataFiles.upload(7, Uint8List.fromList([1, 2, 3]));

      final request = client.requests[1] as http.MultipartRequest;
      expect(request.url.path, '/api/v2/data-files/7/file');
      expect(request.files.single.field, 'files');
      expect(request.files.single.length, 3);
    });

    test(
      'otaFiles.list applies default query parameters and maps items',
      () async {
        final client = QueuedClient();
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

        final spokeZone = SpokeZone(
          config: SpokeZoneConfig.user(userAuth: userCallbacks()),
          httpClient: client,
        );

        final list = await spokeZone.otaFiles.list();
        expect(list.single.module, 'ECU');

        final request = client.requests[1] as http.Request;
        expect(request.url.queryParameters['limit'], '50');
        expect(request.url.queryParameters['offset'], '0');
        expect(request.url.queryParameters.containsKey('module'), isFalse);
        expect(request.url.queryParameters.containsKey('isActive'), isFalse);
      },
    );

    test('otaFiles.list forwards caller query options', () async {
      final client = QueuedClient();
      client.enqueueJson(200, {
        'token': 'user-token',
        'expires': 1,
        'user': {'username': 'u'},
      });
      client.enqueueJson(200, []);

      final spokeZone = SpokeZone(
        config: SpokeZoneConfig.user(userAuth: userCallbacks()),
        httpClient: client,
      );

      await spokeZone.otaFiles.list(
        options: const OtaFilesListOptions(
          searchTerm: 'abc',
          searchFields: 'module,version',
          sort: 'createdDate',
          sortOrder: 'desc',
          module: 'ECU',
          isActive: false,
          limit: 25,
          offset: 10,
        ),
      );

      final request = client.requests[1] as http.Request;
      expect(request.url.queryParameters['searchTerm'], 'abc');
      expect(request.url.queryParameters['searchFields'], 'module,version');
      expect(request.url.queryParameters['sort'], 'createdDate');
      expect(request.url.queryParameters['sortOrder'], 'desc');
      expect(request.url.queryParameters['module'], 'ECU');
      expect(request.url.queryParameters['isActive'], 'false');
      expect(request.url.queryParameters['limit'], '25');
      expect(request.url.queryParameters['offset'], '10');
    });

    test('otaFiles.list maps typed date fields from API payload', () async {
      final client = QueuedClient();
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
          'createdDate': '2026-01-01T10:11:12Z',
          'releaseDate': '2026-02-03T00:00:00Z',
          'releaseNotes': 'notes',
        },
      ]);

      final spokeZone = SpokeZone(
        config: SpokeZoneConfig.user(userAuth: userCallbacks()),
        httpClient: client,
      );

      final file = (await spokeZone.otaFiles.list()).single;
      expect(file.createdAt, DateTime.parse('2026-01-01T10:11:12Z'));
      expect(file.releaseDate, DateTime.parse('2026-02-03T00:00:00Z'));
      expect(file.createdDate, '2026-01-01T10:11:12Z');
    });

    test('otaFiles.list maps invalid or missing typed dates to null', () async {
      final client = QueuedClient();
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
          'createdDate': 'invalid-date',
          'releaseDate': 'also-invalid',
          'releaseNotes': 'notes',
        },
        {
          'id': 2,
          'modelId': 2,
          'moduleId': 3,
          'module': 'TCU',
          'version': '1.2.4',
          'fileLocation': '/bin2',
          'isActive': false,
          'createdDate': '2026-01-01',
          'releaseNotes': 'notes2',
        },
      ]);

      final spokeZone = SpokeZone(
        config: SpokeZoneConfig.user(userAuth: userCallbacks()),
        httpClient: client,
      );

      final files = await spokeZone.otaFiles.list();
      expect(files[0].createdAt, isNull);
      expect(files[0].releaseDate, isNull);
      expect(files[1].createdAt, DateTime.parse('2026-01-01'));
      expect(files[1].releaseDate, isNull);
    });

    test('otaFiles.download returns binary bytes', () async {
      final client = QueuedClient();
      client.enqueueJson(200, {
        'token': 'user-token',
        'expires': 1,
        'user': {'username': 'u'},
      });
      client.enqueueBytes(200, [5, 4, 3]);

      final spokeZone = SpokeZone(
        config: SpokeZoneConfig.user(userAuth: userCallbacks()),
        httpClient: client,
      );

      final bytes = await spokeZone.otaFiles.download(4);
      expect(bytes, Uint8List.fromList([5, 4, 3]));
    });
  });
}
