import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mrs_sdk_flutter/mrs_sdk_flutter.dart';

import 'helpers.dart';

void main() {
  group('LiveData service shape and config', () {
    test('SpokeZone exposes liveData namespace with LiveData type', () {
      final zone = SpokeZone(
        config: SpokeZoneConfig.device(deviceAuth: deviceCallbacks()),
        httpClient: QueuedClient(),
      );

      expect(zone.liveData, isA<LiveData>());
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
      'connect/reconnect asks active auth provider for the current token',
      () async {
        final auth = FakeAccessTokenProvider(tokens: <String>['t-1', 't-2']);
        final transport = FakeLiveDataTransport(
          connectFailuresBeforeSuccess: 1,
        );
        final delays = <Duration>[];

        final zone = SpokeZone(
          config: SpokeZoneConfig.device(deviceAuth: deviceCallbacks()),
          httpClient: QueuedClient(),
          authProvider: auth,
          liveDataTransportFactory: () => transport,
          backoffStrategy: TestBackoffStrategy(
            (retryNumber) =>
                retryNumber == 1 ? const Duration(seconds: 1) : null,
          ),
          delay: (duration) async => delays.add(duration),
        );

        expect(await zone.liveData.connect(), isTrue);
        expect(auth.getAccessTokenCallCount, 2);
        expect(delays, <Duration>[const Duration(seconds: 1)]);
      },
    );

    test('reconnect uses shared custom BackoffStrategy', () async {
      final delays = <Duration>[];
      final zone = SpokeZone(
        config: SpokeZoneConfig.device(deviceAuth: deviceCallbacks()),
        httpClient: QueuedClient(),
        authProvider: FakeAccessTokenProvider(),
        liveDataTransportFactory: () =>
            FakeLiveDataTransport(connectFailuresBeforeSuccess: 1),
        backoffStrategy: TestBackoffStrategy(
          (retryNumber) => retryNumber == 1 ? const Duration(seconds: 2) : null,
        ),
        delay: (duration) async => delays.add(duration),
      );

      expect(await zone.liveData.connect(), isTrue);
      expect(delays, <Duration>[const Duration(seconds: 2)]);
    });

    test('reconnect uses FixedDelayBackoffStrategy by default', () async {
      final delays = <Duration>[];
      final zone = SpokeZone(
        config: SpokeZoneConfig.device(deviceAuth: deviceCallbacks()),
        httpClient: QueuedClient(),
        authProvider: FakeAccessTokenProvider(),
        liveDataTransportFactory: () =>
            FakeLiveDataTransport(connectFailuresBeforeSuccess: 10),
        delay: (duration) async => delays.add(duration),
      );

      expect(await zone.liveData.connect(), isFalse);
      expect(delays, <Duration>[
        const Duration(seconds: 15),
        const Duration(seconds: 30),
        const Duration(seconds: 60),
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
      'registerLocationBroadcast uses fixed topic, default interval, and lat/lon payload',
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
          deviceId: 'dev-1',
          coordinatesProvider: () async =>
              const Coordinates(latitude: 1.2, longitude: 3.4),
        );

        await liveData.connect();
        expect(timerFactory.intervals.single, const Duration(seconds: 15));

        timerFactory.timers.single.tick();
        await Future<void>.delayed(Duration.zero);

        expect(transport.publishCalls.single.topic, 'mrs/d/dev-1/mon/location');
        expect(
          transport.publishCalls.single.payload,
          jsonEncode(<String, dynamic>{'lat': 1.2, 'lon': 3.4}),
        );
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
          deviceId: 'dev-1',
          versionsProvider: () async => <String, String>{
            'module-a': '1.0.0',
            'module-b': '2.0.0',
          },
        );

        await liveData.connect();
        expect(timerFactory.intervals.single, const Duration(seconds: 60));

        timerFactory.timers.single.tick();
        await Future<void>.delayed(Duration.zero);

        expect(transport.publishCalls.single.topic, 'mrs/d/dev-1/mon/versions');
        expect(
          transport.publishCalls.single.payload,
          jsonEncode(<String, dynamic>{
            'module-a': '1.0.0',
            'module-b': '2.0.0',
          }),
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
    List<bool>? publishResults,
  }) : _publishResults = publishResults ?? <bool>[];

  int connectFailuresBeforeSuccess;
  final bool throwOnPublish;
  final List<bool> _publishResults;
  final List<PublishCall> publishCalls = <PublishCall>[];

  bool _connected = false;
  int disconnectCallCount = 0;
  int _connectAttempts = 0;

  @override
  Future<void> connect({
    required String host,
    required int port,
    required bool useTls,
    required String accessToken,
  }) async {
    _connectAttempts += 1;
    if (_connectAttempts <= connectFailuresBeforeSuccess) {
      throw StateError('connect failed');
    }
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    disconnectCallCount += 1;
    _connected = false;
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
    );
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
