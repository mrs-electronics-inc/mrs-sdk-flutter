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

        final spokeZone = SpokeZone(
          config: SpokeZoneConfig.device(deviceAuth: deviceCallbacks()),
          httpClient: client,
          delay: (duration) async => delays.add(duration),
        );

        await spokeZone.devices.get(2);
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

    test('fixed-delay strategy supports optional repeat-last behavior', () {
      const nonRepeating = FixedDelayBackoffStrategy(
        delays: [Duration(seconds: 1), Duration(seconds: 2)],
        repeatLastDelay: false,
      );
      expect(nonRepeating.delayForRetry(1), const Duration(seconds: 1));
      expect(nonRepeating.delayForRetry(2), const Duration(seconds: 2));
      expect(nonRepeating.delayForRetry(3), isNull);

      const repeating = FixedDelayBackoffStrategy(
        delays: [Duration(seconds: 1), Duration(seconds: 2)],
        repeatLastDelay: true,
      );
      expect(repeating.delayForRetry(1), const Duration(seconds: 1));
      expect(repeating.delayForRetry(2), const Duration(seconds: 2));
      expect(repeating.delayForRetry(3), const Duration(seconds: 2));
      expect(repeating.delayForRetry(4), const Duration(seconds: 2));
      expect(repeating.delayForRetry(10), const Duration(seconds: 2));
    });

    test(
      'SpokeZone uses API strategy for auth and endpoint HTTP retries',
      () async {
        final delays = <Duration>[];
        final client = QueuedClient();
        client.enqueueJson(500, {'error': 'auth retry'});
        client.enqueueJson(201, {'token': 'device-token'});
        client.enqueueJson(500, {'error': 'endpoint retry'});
        client.enqueueJson(200, {
          'id': 2,
          'identifier': 'd2',
          'serialNumber': 's2',
          'modelId': 2,
          'name': 'm2',
        });

        final spokeZone = SpokeZone(
          config: SpokeZoneConfig.device(
            deviceAuth: deviceCallbacks(),
            apiBackoffStrategy: const FixedDelayBackoffStrategy(
              delays: [Duration(milliseconds: 111)],
            ),
            liveDataBackoffStrategy: const FixedDelayBackoffStrategy(
              delays: [Duration(milliseconds: 222)],
            ),
          ),
          httpClient: client,
          delay: (duration) async => delays.add(duration),
        );

        await spokeZone.devices.get(2);
        expect(delays, <Duration>[
          const Duration(milliseconds: 111),
          const Duration(milliseconds: 111),
        ]);
      },
    );

    test(
      'maps typed error codes with endpoint/httpStatus/snippet diagnostics',
      () async {
        final client = QueuedClient();
        client.enqueueJson(201, {'token': 'device-token'});
        client.enqueueJson(404, {'message': 'missing resource'});

        final spokeZone = SpokeZone(
          config: SpokeZoneConfig.device(deviceAuth: deviceCallbacks()),
          httpClient: client,
        );

        await expectLater(
          spokeZone.devices.get(99),
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

      final spokeZone = SpokeZone(
        config: SpokeZoneConfig.device(deviceAuth: deviceCallbacks()),
        httpClient: client,
      );

      await expectLater(
        spokeZone.dataFiles.upload(1, Uint8List.fromList([1, 2, 3])),
        throwsA(isA<SpokeZoneException>()),
      );
    });

    test('maps validationError before request dispatch', () async {
      final client = QueuedClient();
      final spokeZone = SpokeZone(
        config: SpokeZoneConfig.device(deviceAuth: deviceCallbacks()),
        httpClient: client,
      );

      await expectLater(
        spokeZone.dataFiles.create('invalid'),
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

    test('401 invalidates token and retries request exactly once', () async {
      final client = QueuedClient();
      client.enqueueJson(201, {'token': 'device-token-1'});
      client.enqueueJson(401, {'error': 'unauthorized'});
      client.enqueueJson(201, {'token': 'device-token-2'});
      client.enqueueJson(200, {
        'id': 2,
        'identifier': 'd2',
        'serialNumber': 's2',
        'modelId': 2,
        'name': 'm2',
      });

      final spokeZone = SpokeZone(
        config: SpokeZoneConfig.device(deviceAuth: deviceCallbacks()),
        httpClient: client,
      );

      final device = await spokeZone.devices.get(2);
      expect(device.id, 2);

      final apiRequests = client.requests
          .where((request) => request.url.path == '/api/v2/devices/2')
          .cast<http.Request>()
          .toList(growable: false);
      expect(apiRequests, hasLength(2));
      expect(apiRequests.first.headers['x-access-token'], 'device-token-1');
      expect(apiRequests.last.headers['x-access-token'], 'device-token-2');
      expect(client.requests, hasLength(4));
    });

    test('repeated 401 does not create retry loops', () async {
      final client = QueuedClient();
      client.enqueueJson(201, {'token': 'device-token-1'});
      client.enqueueJson(401, {'error': 'unauthorized'});
      client.enqueueJson(201, {'token': 'device-token-2'});
      client.enqueueJson(401, {'error': 'unauthorized'});

      final spokeZone = SpokeZone(
        config: SpokeZoneConfig.device(deviceAuth: deviceCallbacks()),
        httpClient: client,
      );

      await expectLater(
        spokeZone.devices.get(2),
        throwsA(
          isA<SpokeZoneException>().having(
            (e) => e.code,
            'code',
            SpokeZoneErrorCode.unauthorized,
          ),
        ),
      );

      final apiRequests = client.requests.where(
        (request) => request.url.path == '/api/v2/devices/2',
      );
      expect(apiRequests, hasLength(2));
      expect(client.requests, hasLength(4));
    });
  });
}
