import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mrs_sdk_flutter/mrs_sdk_flutter.dart';

import 'helpers.dart';

void main() {
  group('LiveData service shape and config', () {
    test('SpokeZone exposes liveData namespace with LiveData type', () {
      final spokeZone = SpokeZone(
        config: SpokeZoneConfig.device(deviceAuth: deviceCallbacks()),
        httpClient: QueuedClient(),
      );

      expect(spokeZone.liveData, isA<LiveData>());
    });

    test(
      'LiveData lifecycle starts disconnected and supports connect/disconnect',
      () async {
        final transport = FakeLiveDataTransport();
        final liveData = LiveData(
          mqttHost: 'io.spoke.zone',
          mqttPort: 8883,
          mqttUseTls: true,
          authProvider: FakeAccessTokenProvider(),
          transportFactory: () => transport,
        );

        expect(liveData.isConnected.value, isFalse);
        expect(await liveData.connect(), isTrue);
        expect(liveData.isConnected.value, isTrue);

        await liveData.disconnect();
        expect(liveData.isConnected.value, isFalse);
      },
    );

    test(
      'SpokeZoneConfig has MQTT defaults and supports test-only unencrypted mode',
      () {
        final defaults = SpokeZoneConfig.device(deviceAuth: deviceCallbacks());
        expect(defaults.mqttHost, 'io.spoke.zone');
        expect(defaults.mqttPort, 8883);
        expect(defaults.mqttUseTls, isTrue);

        final unencrypted = SpokeZoneConfig.user(
          userAuth: userCallbacks(),
          mqttHost: 'localhost',
          mqttPort: 1883,
          mqttUseTls: false,
        );
        expect(unencrypted.mqttHost, 'localhost');
        expect(unencrypted.mqttPort, 1883);
        expect(unencrypted.mqttUseTls, isFalse);
      },
    );
  });

  group('LiveData auth and reconnect behavior', () {
    test(
      'connect retries on timeout failures and enforces connect timeout',
      () async {
        final delays = <Duration>[];
        final transport = TimeoutEnforcingLiveDataTransport();
        final spokeZone = SpokeZone(
          config: SpokeZoneConfig.device(
            deviceAuth: deviceCallbacks(),
            liveDataBackoffStrategy: TestBackoffStrategy(
              (retryNumber) =>
                  retryNumber <= 2 ? const Duration(milliseconds: 250) : null,
            ),
          ),
          httpClient: QueuedClient(),
          authProvider: FakeAccessTokenProvider(),
          liveDataTransportFactory: () => transport,
          liveDataConnectTimeout: const Duration(seconds: 3),
          delay: (duration) async => delays.add(duration),
        );

        expect(await spokeZone.liveData.connect(), isFalse);
        expect(transport.timeoutFailures, 3);
        expect(transport.connectTimeouts, <Duration>[
          const Duration(seconds: 3),
          const Duration(seconds: 3),
          const Duration(seconds: 3),
        ]);
        expect(delays, <Duration>[
          const Duration(milliseconds: 250),
          const Duration(milliseconds: 250),
        ]);
      },
    );

    test(
      'automatic reconnect resumes connection after unexpected disconnect',
      () async {
        final delays = <Duration>[];
        final transport = FakeLiveDataTransport(
          connectResults: <bool>[true, false, true],
        );
        final spokeZone = SpokeZone(
          config: SpokeZoneConfig.device(
            deviceAuth: deviceCallbacks(),
            liveDataBackoffStrategy: TestBackoffStrategy(
              (retryNumber) =>
                  retryNumber == 1 ? const Duration(milliseconds: 200) : null,
            ),
          ),
          httpClient: QueuedClient(),
          authProvider: FakeAccessTokenProvider(),
          liveDataTransportFactory: () => transport,
          delay: (duration) async => delays.add(duration),
        );

        await spokeZone.liveData.connect();
        expect(spokeZone.liveData.isConnected.value, isTrue);

        transport.simulateUnexpectedDisconnect();
        await _waitForConnectAttempts(transport, 3);

        expect(spokeZone.liveData.isConnected.value, isTrue);
        expect(delays, <Duration>[const Duration(milliseconds: 200)]);
      },
    );

    test('reconnect attempts resolve the current token each attempt', () async {
      final transport = FakeLiveDataTransport(
        connectResults: <bool>[true, false, true],
      );
      final auth = FakeAccessTokenProvider(
        tokens: <String>['t-1', 't-2', 't-3'],
      );
      final spokeZone = SpokeZone(
        config: SpokeZoneConfig.device(
          deviceAuth: deviceCallbacks(),
          liveDataBackoffStrategy: TestBackoffStrategy(
            (retryNumber) =>
                retryNumber == 1 ? const Duration(milliseconds: 100) : null,
          ),
        ),
        httpClient: QueuedClient(),
        authProvider: auth,
        liveDataTransportFactory: () => transport,
        delay: (_) async {},
      );

      await spokeZone.liveData.connect();
      transport.simulateUnexpectedDisconnect();
      await _waitForConnectAttempts(transport, 3);

      expect(auth.getAccessTokenCallCount, 3);
      expect(transport.connectTokens, <String>['t-1', 't-2', 't-3']);
    });

    test('explicit disconnect disables reconnect intent', () async {
      final delays = <Duration>[];
      final releaseDelay = Completer<void>();
      final transport = FakeLiveDataTransport(
        connectResults: <bool>[true, false, true],
      );
      final spokeZone = SpokeZone(
        config: SpokeZoneConfig.device(
          deviceAuth: deviceCallbacks(),
          liveDataBackoffStrategy: TestBackoffStrategy(
            (retryNumber) =>
                retryNumber == 1 ? const Duration(milliseconds: 300) : null,
          ),
        ),
        httpClient: QueuedClient(),
        authProvider: FakeAccessTokenProvider(),
        liveDataTransportFactory: () => transport,
        delay: (duration) async {
          delays.add(duration);
          await releaseDelay.future;
        },
      );

      await spokeZone.liveData.connect();
      transport.simulateUnexpectedDisconnect();
      await _waitForConnectAttempts(transport, 2);

      await spokeZone.liveData.disconnect();
      releaseDelay.complete();
      await Future<void>.delayed(Duration.zero);

      expect(spokeZone.liveData.isConnected.value, isFalse);
      expect(transport.connectAttemptCount, 2);
      expect(delays, <Duration>[const Duration(milliseconds: 300)]);
    });

    test(
      'connect/reconnect asks active auth provider for the current token',
      () async {
        final auth = FakeAccessTokenProvider(tokens: <String>['t-1', 't-2']);
        final transport = FakeLiveDataTransport(
          connectFailuresBeforeSuccess: 1,
        );
        final delays = <Duration>[];

        final spokeZone = SpokeZone(
          config: SpokeZoneConfig.device(
            deviceAuth: deviceCallbacks(),
            liveDataBackoffStrategy: TestBackoffStrategy(
              (retryNumber) =>
                  retryNumber == 1 ? const Duration(seconds: 1) : null,
            ),
          ),
          httpClient: QueuedClient(),
          authProvider: auth,
          liveDataTransportFactory: () => transport,
          delay: (duration) async => delays.add(duration),
        );

        expect(await spokeZone.liveData.connect(), isTrue);
        expect(auth.getAccessTokenCallCount, 2);
        expect(delays, <Duration>[const Duration(seconds: 1)]);
      },
    );

    test(
      'reconnect uses live-data strategy independent from API strategy',
      () async {
        final delays = <Duration>[];
        final spokeZone = SpokeZone(
          config: SpokeZoneConfig.device(
            deviceAuth: deviceCallbacks(),
            apiBackoffStrategy: const FixedDelayBackoffStrategy(
              delays: [Duration(seconds: 9)],
            ),
            liveDataBackoffStrategy: TestBackoffStrategy(
              (retryNumber) =>
                  retryNumber == 1 ? const Duration(seconds: 2) : null,
            ),
          ),
          httpClient: QueuedClient(),
          authProvider: FakeAccessTokenProvider(),
          liveDataTransportFactory: () =>
              FakeLiveDataTransport(connectFailuresBeforeSuccess: 1),
          delay: (duration) async => delays.add(duration),
        );

        expect(await spokeZone.liveData.connect(), isTrue);
        expect(delays, <Duration>[const Duration(seconds: 2)]);
      },
    );

    test('reconnect uses FixedDelayBackoffStrategy by default', () async {
      final delays = <Duration>[];
      final spokeZone = SpokeZone(
        config: SpokeZoneConfig.device(deviceAuth: deviceCallbacks()),
        httpClient: QueuedClient(),
        authProvider: FakeAccessTokenProvider(),
        liveDataTransportFactory: () =>
            FakeLiveDataTransport(connectFailuresBeforeSuccess: 8),
        delay: (duration) async => delays.add(duration),
      );

      expect(await spokeZone.liveData.connect(), isTrue);
      expect(delays, <Duration>[
        const Duration(seconds: 5),
        const Duration(seconds: 15),
        const Duration(seconds: 30),
        const Duration(seconds: 60),
        const Duration(seconds: 120),
        const Duration(seconds: 300),
        const Duration(seconds: 300),
        const Duration(seconds: 300),
      ]);
    });

    test(
      'disconnect during in-flight connect resolves false and stays disconnected',
      () async {
        final timerFactory = ManualTimerFactory();
        final transport = BlockingConnectLiveDataTransport();
        final liveData = LiveData(
          mqttHost: 'io.spoke.zone',
          mqttPort: 8883,
          mqttUseTls: true,
          authProvider: FakeAccessTokenProvider(),
          transportFactory: () => transport,
          timerFactory: timerFactory.create,
        );
        liveData.registerJsonBroadcast(
          topic: 'topic/race',
          payloadProvider: () async => <String, dynamic>{'ok': true},
        );

        final connectFuture = liveData.connect();
        await transport.connectStarted;

        await liveData.disconnect();
        transport.completeConnect();

        expect(await connectFuture, isFalse);
        expect(liveData.isConnected.value, isFalse);
        expect(timerFactory.timers, isEmpty);
      },
    );

    test('disconnect then reconnect reuses in-flight connect', () async {
      final transport = BlockingConnectLiveDataTransport();
      final liveData = LiveData(
        mqttHost: 'io.spoke.zone',
        mqttPort: 8883,
        mqttUseTls: true,
        authProvider: FakeAccessTokenProvider(),
        transportFactory: () => transport,
      );

      final firstConnect = liveData.connect();
      await transport.connectStarted;

      await liveData.disconnect();
      final secondConnect = liveData.connect();

      expect(identical(firstConnect, secondConnect), isTrue);

      transport.completeConnect();
      expect(await firstConnect, isTrue);
      expect(await secondConnect, isTrue);
      expect(liveData.isConnected.value, isTrue);
      expect(transport.connectCallCount, 1);
    });

    test('connect is idempotent when already connected', () async {
      final transport = FakeLiveDataTransport();
      final liveData = LiveData(
        mqttHost: 'io.spoke.zone',
        mqttPort: 8883,
        mqttUseTls: true,
        authProvider: FakeAccessTokenProvider(),
        transportFactory: () => transport,
      );

      expect(await liveData.connect(), isTrue);
      expect(await liveData.connect(), isTrue);
      expect(transport.connectAttemptCount, 1);
      expect(liveData.isConnected.value, isTrue);
    });

    test('unexpected transport disconnect updates isConnected', () async {
      final transport = FakeLiveDataTransport();
      final liveData = LiveData(
        mqttHost: 'io.spoke.zone',
        mqttPort: 8883,
        mqttUseTls: true,
        authProvider: FakeAccessTokenProvider(),
        transportFactory: () => transport,
      );

      await liveData.connect();
      expect(liveData.isConnected.value, isTrue);

      transport.simulateUnexpectedDisconnect();
      expect(liveData.isConnected.value, isFalse);
    });
  });

  group('LiveData publish contract', () {
    test(
      'publishJson returns true on success and false when disconnected',
      () async {
        final transport = FakeLiveDataTransport();
        final liveData = LiveData(
          mqttHost: 'io.spoke.zone',
          mqttPort: 8883,
          mqttUseTls: true,
          authProvider: FakeAccessTokenProvider(),
          transportFactory: () => transport,
        );

        expect(
          await liveData.publishJson('topic/a', <String, dynamic>{'x': 1}),
          isFalse,
        );

        await liveData.connect();
        expect(
          await liveData.publishJson('topic/a', <String, dynamic>{'x': 1}),
          isTrue,
        );
      },
    );

    test(
      'publishJson returns false on transport failure without throwing',
      () async {
        final transport = FakeLiveDataTransport(throwOnPublish: true);
        final liveData = LiveData(
          mqttHost: 'io.spoke.zone',
          mqttPort: 8883,
          mqttUseTls: true,
          authProvider: FakeAccessTokenProvider(),
          transportFactory: () => transport,
        );

        await liveData.connect();
        expect(
          await liveData.publishJson('topic/a', <String, dynamic>{'x': 1}),
          isFalse,
        );
      },
    );

    test('publishJson supports retained-message option', () async {
      final transport = FakeLiveDataTransport();
      final liveData = LiveData(
        mqttHost: 'io.spoke.zone',
        mqttPort: 8883,
        mqttUseTls: true,
        authProvider: FakeAccessTokenProvider(),
        transportFactory: () => transport,
      );

      await liveData.connect();
      await liveData.publishJson('topic/a', <String, dynamic>{
        'x': 1,
      }, retained: true);

      expect(transport.publishCalls.single.retained, isTrue);
    });

    test('publishJson validates topic and payload serialization', () async {
      final liveData = LiveData(
        mqttHost: 'io.spoke.zone',
        mqttPort: 8883,
        mqttUseTls: true,
        authProvider: FakeAccessTokenProvider(),
        transportFactory: FakeLiveDataTransport.new,
      );

      await expectLater(
        () => liveData.publishJson('', <String, dynamic>{'x': 1}),
        throwsA(
          isA<SpokeZoneException>().having(
            (e) => e.code,
            'code',
            SpokeZoneErrorCode.validationError,
          ),
        ),
      );

      await expectLater(
        () => liveData.publishJson('topic/a', <String, dynamic>{
          'invalid': Object(),
        }),
        throwsA(
          isA<SpokeZoneException>().having(
            (e) => e.code,
            'code',
            SpokeZoneErrorCode.validationError,
          ),
        ),
      );
    });

    test('publishJson serializes payload before dispatch', () async {
      final transport = FakeLiveDataTransport();
      final liveData = LiveData(
        mqttHost: 'io.spoke.zone',
        mqttPort: 8883,
        mqttUseTls: true,
        authProvider: FakeAccessTokenProvider(),
        transportFactory: () => transport,
      );

      await liveData.connect();
      final payload = <String, dynamic>{'a': 1, 'b': 'ok'};
      await liveData.publishJson('topic/a', payload);

      expect(transport.publishCalls.single.payload, jsonEncode(payload));
    });
  });

  group('LiveData periodic broadcasting', () {
    test(
      'generic periodic registration supports custom topics and nullable callbacks',
      () async {
        final timerFactory = ManualTimerFactory();
        final transport = FakeLiveDataTransport();
        final liveData = LiveData(
          mqttHost: 'io.spoke.zone',
          mqttPort: 8883,
          mqttUseTls: true,
          authProvider: FakeAccessTokenProvider(),
          transportFactory: () => transport,
          timerFactory: timerFactory.create,
        );

        var tickCount = 0;
        liveData.registerJsonBroadcast(
          topic: 'custom/topic',
          interval: const Duration(seconds: 3),
          payloadProvider: () async {
            tickCount += 1;
            if (tickCount == 1) {
              return null;
            }
            return <String, dynamic>{'tick': tickCount};
          },
        );

        await liveData.connect();
        expect(transport.publishCalls, isEmpty);

        timerFactory.timers.single.tick();
        await Future<void>.delayed(Duration.zero);
        expect(transport.publishCalls, isEmpty);

        timerFactory.timers.single.tick();
        await Future<void>.delayed(Duration.zero);
        expect(transport.publishCalls.single.topic, 'custom/topic');
      },
    );

    test(
      'scheduler waits for first interval tick and publishes on cadence',
      () async {
        final timerFactory = ManualTimerFactory();
        final transport = FakeLiveDataTransport();
        final liveData = LiveData(
          mqttHost: 'io.spoke.zone',
          mqttPort: 8883,
          mqttUseTls: true,
          authProvider: FakeAccessTokenProvider(),
          transportFactory: () => transport,
          timerFactory: timerFactory.create,
        );

        liveData.registerJsonBroadcast(
          topic: 'custom/topic',
          interval: const Duration(seconds: 5),
          payloadProvider: () async => <String, dynamic>{'ok': true},
        );
        await liveData.connect();

        expect(transport.publishCalls, isEmpty);
        timerFactory.timers.single.tick();
        await Future<void>.delayed(Duration.zero);
        timerFactory.timers.single.tick();
        await Future<void>.delayed(Duration.zero);

        expect(transport.publishCalls, hasLength(2));
        expect(timerFactory.intervals.single, const Duration(seconds: 5));
      },
    );

    test(
      'cancel only stops one registration; disconnect pauses; connect resumes',
      () async {
        final timerFactory = ManualTimerFactory();
        final transport = FakeLiveDataTransport();
        final liveData = LiveData(
          mqttHost: 'io.spoke.zone',
          mqttPort: 8883,
          mqttUseTls: true,
          authProvider: FakeAccessTokenProvider(),
          transportFactory: () => transport,
          timerFactory: timerFactory.create,
        );

        final a = liveData.registerJsonBroadcast(
          topic: 'topic/a',
          interval: const Duration(seconds: 1),
          payloadProvider: () async => <String, dynamic>{'a': 1},
        );
        liveData.registerJsonBroadcast(
          topic: 'topic/b',
          interval: const Duration(seconds: 2),
          payloadProvider: () async => <String, dynamic>{'b': 1},
        );

        await liveData.connect();
        timerFactory.timers[0].tick();
        timerFactory.timers[1].tick();
        await Future<void>.delayed(Duration.zero);
        expect(transport.publishCalls, hasLength(2));

        await a.cancel();
        timerFactory.timers[0].tick();
        timerFactory.timers[1].tick();
        await Future<void>.delayed(Duration.zero);
        expect(transport.publishCalls, hasLength(3));
        expect(transport.publishCalls.last.topic, 'topic/b');

        await liveData.disconnect();
        timerFactory.timers[1].tick();
        await Future<void>.delayed(Duration.zero);
        expect(transport.publishCalls, hasLength(3));

        await liveData.connect();
        timerFactory.timers[2].tick();
        await Future<void>.delayed(Duration.zero);
        expect(transport.publishCalls, hasLength(4));
        expect(transport.publishCalls.last.topic, 'topic/b');
      },
    );

    test(
      'cancel allows one in-flight publish and stops subsequent ticks',
      () async {
        final timerFactory = ManualTimerFactory();
        final transport = FakeLiveDataTransport();
        final liveData = LiveData(
          mqttHost: 'io.spoke.zone',
          mqttPort: 8883,
          mqttUseTls: true,
          authProvider: FakeAccessTokenProvider(),
          transportFactory: () => transport,
          timerFactory: timerFactory.create,
        );
        final payloadStarted = Completer<void>();
        final releasePayload = Completer<void>();

        final registration = liveData.registerJsonBroadcast(
          topic: 'topic/in-flight',
          interval: const Duration(seconds: 1),
          payloadProvider: () async {
            if (!payloadStarted.isCompleted) {
              payloadStarted.complete();
            }
            await releasePayload.future;
            return <String, dynamic>{'ok': true};
          },
        );

        await liveData.connect();

        timerFactory.timers.single.tick();
        await payloadStarted.future;

        await registration.cancel();
        releasePayload.complete();
        await Future<void>.delayed(Duration.zero);

        expect(transport.publishCalls, hasLength(1));
        expect(transport.publishCalls.single.topic, 'topic/in-flight');
        expect(registration.status.state, LiveDataRegistrationState.canceled);

        timerFactory.timers.single.tick();
        await Future<void>.delayed(Duration.zero);
        expect(transport.publishCalls, hasLength(1));
      },
    );

    test(
      'registerLocationBroadcast uses fixed topic, default interval, retained publish, and location payload',
      () async {
        final timerFactory = ManualTimerFactory();
        final transport = FakeLiveDataTransport();
        final liveData = LiveData(
          mqttHost: 'io.spoke.zone',
          mqttPort: 8883,
          mqttUseTls: true,
          authProvider: FakeAccessTokenProvider(),
          transportFactory: () => transport,
          timerFactory: timerFactory.create,
        );

        liveData.registerLocationBroadcast(
          deviceId: 1,
          locationProvider: () async => const LocationData(
            latitude: 1.2,
            longitude: 3.4,
            heading: 45.0,
            speed: 12.5,
          ),
        );

        await liveData.connect();
        expect(timerFactory.intervals.single, const Duration(seconds: 15));

        timerFactory.timers.single.tick();
        await Future<void>.delayed(Duration.zero);

        expect(transport.publishCalls.single.topic, 'mrs/d/1/mon/location');
        expect(
          transport.publishCalls.single.payload,
          jsonEncode(<String, dynamic>{
            'lat': 1.2,
            'lon': 3.4,
            'heading': 45.0,
            'speed': 12.5,
          }),
        );
        expect(transport.publishCalls.single.retained, isTrue);
      },
    );

    test(
      'registerSoftwareVersionsBroadcast uses fixed topic, default interval, and flat payload',
      () async {
        final timerFactory = ManualTimerFactory();
        final transport = FakeLiveDataTransport();
        final liveData = LiveData(
          mqttHost: 'io.spoke.zone',
          mqttPort: 8883,
          mqttUseTls: true,
          authProvider: FakeAccessTokenProvider(),
          transportFactory: () => transport,
          timerFactory: timerFactory.create,
        );

        liveData.registerSoftwareVersionsBroadcast(
          deviceId: 1,
          versionsProvider: () async => <String, String>{
            'module-a': '1.0.0',
            'module-b': '2.0.0',
          },
        );

        await liveData.connect();
        expect(timerFactory.intervals.single, const Duration(seconds: 60));

        timerFactory.timers.single.tick();
        await Future<void>.delayed(Duration.zero);

        expect(transport.publishCalls.single.topic, 'mrs/d/1/mon/versions');
        expect(
          transport.publishCalls.single.payload,
          jsonEncode(<String, dynamic>{
            'module-a': '1.0.0',
            'module-b': '2.0.0',
          }),
        );
      },
    );

    test(
      'registerLocationBroadcast rejects non-positive device IDs',
      () {
        final liveData = LiveData(
          mqttHost: 'io.spoke.zone',
          mqttPort: 8883,
          mqttUseTls: true,
          authProvider: FakeAccessTokenProvider(),
          transportFactory: () => FakeLiveDataTransport(),
        );

        expect(
          () => liveData.registerLocationBroadcast(
            deviceId: 0,
            locationProvider: () async => null,
          ),
          throwsA(
            isA<SpokeZoneException>().having(
              (e) => e.code,
              'code',
              SpokeZoneErrorCode.validationError,
            ),
          ),
        );
      },
    );

    test(
      'registerSoftwareVersionsBroadcast rejects non-positive device IDs',
      () {
        final liveData = LiveData(
          mqttHost: 'io.spoke.zone',
          mqttPort: 8883,
          mqttUseTls: true,
          authProvider: FakeAccessTokenProvider(),
          transportFactory: () => FakeLiveDataTransport(),
        );

        expect(
          () => liveData.registerSoftwareVersionsBroadcast(
            deviceId: -1,
            versionsProvider: () async => <String, String>{},
          ),
          throwsA(
            isA<SpokeZoneException>().having(
              (e) => e.code,
              'code',
              SpokeZoneErrorCode.validationError,
            ),
          ),
        );
      },
    );
  });

  group('LiveData registration status', () {
    test(
      'status tracks idle, failed, running, and canceled transitions',
      () async {
        final timerFactory = ManualTimerFactory();
        final transport = FakeLiveDataTransport(
          publishResults: <bool>[false, true],
        );
        final now = DateTime.utc(2026, 3, 3, 12, 0, 0);
        final liveData = LiveData(
          mqttHost: 'io.spoke.zone',
          mqttPort: 8883,
          mqttUseTls: true,
          authProvider: FakeAccessTokenProvider(),
          transportFactory: () => transport,
          timerFactory: timerFactory.create,
          now: () => now,
        );

        final registration = liveData.registerJsonBroadcast(
          topic: 'topic/status',
          payloadProvider: () async => <String, dynamic>{'ok': true},
        );

        expect(registration.status.state, LiveDataRegistrationState.idle);
        expect(registration.status.lastSuccessAt, isNull);
        expect(registration.status.consecutiveFailures, 0);

        await liveData.connect();

        timerFactory.timers.single.tick();
        await Future<void>.delayed(Duration.zero);
        expect(registration.status.state, LiveDataRegistrationState.failed);
        expect(registration.status.lastSuccessAt, isNull);
        expect(registration.status.consecutiveFailures, 1);

        timerFactory.timers.single.tick();
        await Future<void>.delayed(Duration.zero);
        expect(registration.status.state, LiveDataRegistrationState.running);
        expect(registration.status.lastSuccessAt, now);
        expect(registration.status.consecutiveFailures, 0);

        await registration.cancel();
        expect(registration.status.state, LiveDataRegistrationState.canceled);
      },
    );
  });
}

Future<void> _waitForConnectAttempts(
  FakeLiveDataTransport transport,
  int attempts,
) async {
  for (var i = 0; i < 1000; i += 1) {
    if (transport.connectAttemptCount >= attempts) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }

  fail(
    'Timed out waiting for $attempts connect attempts; saw ${transport.connectAttemptCount}.',
  );
}

class FakeAccessTokenProvider implements AccessTokenProvider {
  FakeAccessTokenProvider({List<String>? tokens})
    : _tokens = tokens ?? <String>['token'];

  final List<String> _tokens;
  int getAccessTokenCallCount = 0;

  @override
  Future<String> getAccessToken() async {
    getAccessTokenCallCount += 1;
    if (_tokens.length == 1) {
      return _tokens.single;
    }
    final index = getAccessTokenCallCount - 1;
    if (index >= _tokens.length) {
      return _tokens.last;
    }
    return _tokens[index];
  }
}

class FakeLiveDataTransport implements LiveDataTransport {
  FakeLiveDataTransport({
    this.connectFailuresBeforeSuccess = 0,
    this.throwOnPublish = false,
    List<bool>? connectResults,
    List<bool>? publishResults,
  }) : _connectResults = connectResults ?? <bool>[],
       _publishResults = publishResults ?? <bool>[];

  int connectFailuresBeforeSuccess;
  final bool throwOnPublish;
  final List<bool> _connectResults;
  final List<bool> _publishResults;
  final List<PublishCall> publishCalls = <PublishCall>[];
  final List<String> connectTokens = <String>[];
  final List<Duration> connectTimeouts = <Duration>[];

  bool _connected = false;
  int disconnectCallCount = 0;
  int _connectAttempts = 0;
  void Function()? _onDisconnected;

  int get connectAttemptCount => _connectAttempts;

  @override
  Future<void> connect({
    required String host,
    required int port,
    required bool useTls,
    required String accessToken,
    required Duration connectTimeout,
    required void Function() onDisconnected,
  }) async {
    _connectAttempts += 1;
    connectTokens.add(accessToken);
    connectTimeouts.add(connectTimeout);
    _onDisconnected = onDisconnected;
    if (_connectAttempts <= connectFailuresBeforeSuccess) {
      throw StateError('connect failed');
    }

    if (_connectResults.isNotEmpty && !_connectResults.removeAt(0)) {
      throw StateError('connect failed');
    }

    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    disconnectCallCount += 1;
    _connected = false;
  }

  void simulateUnexpectedDisconnect() {
    _connected = false;
    _onDisconnected?.call();
  }

  @override
  Future<bool> publish({
    required String topic,
    required String payload,
    required bool retained,
  }) async {
    if (throwOnPublish) {
      throw StateError('publish failed');
    }
    publishCalls.add(
      PublishCall(topic: topic, payload: payload, retained: retained),
    );
    if (!_connected) {
      return false;
    }
    if (_publishResults.isEmpty) {
      return true;
    }
    return _publishResults.removeAt(0);
  }
}

class BlockingConnectLiveDataTransport extends FakeLiveDataTransport {
  final Completer<void> _connectStarted = Completer<void>();
  final Completer<void> _allowConnect = Completer<void>();

  Future<void> get connectStarted => _connectStarted.future;
  int connectCallCount = 0;

  void completeConnect() {
    if (!_allowConnect.isCompleted) {
      _allowConnect.complete();
    }
  }

  @override
  Future<void> connect({
    required String host,
    required int port,
    required bool useTls,
    required String accessToken,
    required Duration connectTimeout,
    required void Function() onDisconnected,
  }) async {
    connectCallCount += 1;
    if (!_connectStarted.isCompleted) {
      _connectStarted.complete();
    }
    await _allowConnect.future;
    await super.connect(
      host: host,
      port: port,
      useTls: useTls,
      accessToken: accessToken,
      connectTimeout: connectTimeout,
      onDisconnected: onDisconnected,
    );
  }
}

class TimeoutEnforcingLiveDataTransport extends FakeLiveDataTransport {
  int timeoutFailures = 0;

  @override
  Future<void> connect({
    required String host,
    required int port,
    required bool useTls,
    required String accessToken,
    required Duration connectTimeout,
    required void Function() onDisconnected,
  }) async {
    await super.connect(
      host: host,
      port: port,
      useTls: useTls,
      accessToken: accessToken,
      connectTimeout: connectTimeout,
      onDisconnected: onDisconnected,
    );

    timeoutFailures += 1;
    throw TimeoutException('connect timed out', connectTimeout);
  }
}

class PublishCall {
  PublishCall({
    required this.topic,
    required this.payload,
    required this.retained,
  });

  final String topic;
  final String payload;
  final bool retained;
}

class ManualTimerFactory {
  final List<ManualTimer> timers = <ManualTimer>[];
  final List<Duration> intervals = <Duration>[];

  PeriodicTimer create(Duration interval, void Function() onTick) {
    intervals.add(interval);
    final timer = ManualTimer(onTick);
    timers.add(timer);
    return timer;
  }
}

class ManualTimer implements PeriodicTimer {
  ManualTimer(this._onTick);

  final void Function() _onTick;
  bool _canceled = false;

  @override
  void cancel() {
    _canceled = true;
  }

  void tick() {
    if (_canceled) {
      return;
    }
    _onTick();
  }
}
