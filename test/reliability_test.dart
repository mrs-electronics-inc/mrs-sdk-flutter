import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mrs_sdk_flutter/mrs_sdk_flutter.dart';

import 'helpers.dart';

void main() {
  group('Reliability and errors', () {
    test(
      'retries transport errors + 429 + 5xx using 15s -> 30s -> 60s delays',
      () async {
        final delays = <Duration>[];
        final client = QueuedClient();
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
          config: SpokeZoneConfig.device(deviceAuth: deviceCallbacks()),
          httpClient: client,
          delay: (duration) async => delays.add(duration),
        );

        await zone.devices.get(2);
        expect(delays, [
          const Duration(seconds: 15),
          const Duration(seconds: 30),
          const Duration(seconds: 60),
        ]);
      },
    );

    test('does not retry non-429 4xx responses', () async {
      final client = QueuedClient();
      client.enqueueJson(401, {'error': 'unauthorized'});

      final auth = DeviceAuth(
        baseUri: Uri.parse('https://api.spoke.zone'),
        callbacks: deviceCallbacks(),
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

    test(
      'backoff abstraction supports default and custom strategy behavior',
      () async {
        final defaults = FixedDelayBackoffStrategy();
        expect(defaults.delayForRetry(1), const Duration(seconds: 15));
        expect(defaults.delayForRetry(2), const Duration(seconds: 30));
        expect(defaults.delayForRetry(3), const Duration(seconds: 60));
        expect(defaults.delayForRetry(4), isNull);

        final called = <int>[];
        final custom = TestBackoffStrategy((retryNumber) {
          called.add(retryNumber);
          return retryNumber == 1 ? Duration.zero : null;
        });

        final client = QueuedClient();
        client.enqueueJson(500, {'error': 'server'});
        client.enqueueJson(201, {'token': 'token'});

        final auth = DeviceAuth(
          baseUri: Uri.parse('https://api.spoke.zone'),
          callbacks: deviceCallbacks(),
          httpClient: client,
          backoffStrategy: custom,
          delay: (_) async {},
        );

        expect(await auth.login(), 'token');
        expect(called, [1]);
      },
    );

    test(
      'maps typed error codes with endpoint/httpStatus/snippet diagnostics',
      () async {
        final client = QueuedClient();
        client.enqueueJson(201, {'token': 'device-token'});
        client.enqueueJson(404, {'message': 'missing resource'});

        final zone = SpokeZone(
          config: SpokeZoneConfig.device(deviceAuth: deviceCallbacks()),
          httpClient: client,
        );

        await expectLater(
          zone.devices.get(99),
          throwsA(
            isA<SpokeZoneException>()
                .having((e) => e.code, 'code', SpokeZoneErrorCode.notFound)
                .having((e) => e.endpoint, 'endpoint', '/api/v2/devices/99')
                .having((e) => e.httpStatus, 'httpStatus', 404)
                .having(
                  (e) => e.responseSnippet,
                  'responseSnippet',
                  contains('missing'),
                ),
          ),
        );
      },
    );

    test('includes retry metadata when retry limit is reached', () async {
      final client = QueuedClient();
      client.enqueueJson(500, {'error': 's1'});
      client.enqueueJson(500, {'error': 's2'});
      client.enqueueJson(500, {'error': 's3'});
      client.enqueueJson(500, {'error': 's4'});

      final auth = DeviceAuth(
        baseUri: Uri.parse('https://api.spoke.zone'),
        callbacks: deviceCallbacks(),
        httpClient: client,
        delay: (_) async {},
      );

      await expectLater(
        auth.login(),
        throwsA(
          isA<SpokeZoneException>()
              .having(
                (e) => e.code,
                'code',
                SpokeZoneErrorCode.retryLimitReached,
              )
              .having((e) => e.retryAttempt, 'retryAttempt', 4)
              .having((e) => e.retryAfter, 'retryAfter', isNull),
        ),
      );
    });

    test('public APIs throw only SDK typed exceptions', () async {
      final client = QueuedClient();
      client.enqueueJson(201, {'token': 'device-token'});
      client.enqueueException(http.ClientException('socket closed'));

      final zone = SpokeZone(
        config: SpokeZoneConfig.device(deviceAuth: deviceCallbacks()),
        httpClient: client,
      );

      await expectLater(
        zone.dataFiles.upload(1, Uint8List.fromList([1, 2, 3])),
        throwsA(isA<SpokeZoneException>()),
      );
    });

    test('maps validationError before request dispatch', () async {
      final client = QueuedClient();
      final zone = SpokeZone(
        config: SpokeZoneConfig.device(deviceAuth: deviceCallbacks()),
        httpClient: client,
      );

      await expectLater(
        zone.dataFiles.create('invalid'),
        throwsA(
          isA<SpokeZoneException>().having(
            (e) => e.code,
            'code',
            SpokeZoneErrorCode.validationError,
          ),
        ),
      );
      expect(client.requests, isEmpty);
    });
  });
}
