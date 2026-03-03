import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'access_token_provider.dart';
import 'errors.dart';
import 'retry.dart';
import 'models/coordinates.dart';

/// Registration states for periodic live-data jobs.
enum LiveDataRegistrationState { idle, running, failed, canceled }

/// Snapshot of one periodic registration's current status.
class LiveDataRegistrationStatus {
  /// Creates an immutable registration status snapshot.
  const LiveDataRegistrationStatus({
    required this.state,
    required this.lastSuccessAt,
    required this.consecutiveFailures,
  });

  /// Current state for this registration.
  final LiveDataRegistrationState state;

  /// Timestamp of the latest successful publish, if any.
  final DateTime? lastSuccessAt;

  /// Count of consecutive failed publish attempts.
  final int consecutiveFailures;
}

/// Async provider used for periodic JSON payload generation.
typedef LiveDataPayloadProvider = Future<Map<String, dynamic>?> Function();

/// Transport abstraction used by [LiveData].
abstract interface class LiveDataTransport {
  /// Opens an MQTT session with token-authenticated connection settings.
  Future<void> connect({
    required String host,
    required int port,
    required bool useTls,
    required String accessToken,
  });

  /// Closes the active MQTT session.
  Future<void> disconnect();

  /// Publishes a serialized JSON payload to the given topic.
  Future<bool> publish({
    required String topic,
    required String payload,
    required bool retained,
  });
}

/// Factory for creating a [LiveDataTransport] instance.
typedef LiveDataTransportFactory = LiveDataTransport Function();

/// Minimal periodic timer contract used for scheduler injection.
abstract interface class PeriodicTimer {
  /// Cancels future ticks.
  void cancel();
}

/// Factory for creating periodic timers.
typedef PeriodicTimerFactory =
    PeriodicTimer Function(Duration interval, void Function() onTick);

/// Handle returned by periodic registration APIs.
class LiveDataRegistration {
  LiveDataRegistration._(this._cancel, this._statusNotifier);

  final Future<void> Function() _cancel;
  final ValueNotifier<LiveDataRegistrationStatus> _statusNotifier;

  /// Current registration status snapshot.
  LiveDataRegistrationStatus get status => _statusNotifier.value;

  /// Observable status updates for this registration.
  ValueListenable<LiveDataRegistrationStatus> get statusListenable =>
      _statusNotifier;

  /// Cancels this registration.
  Future<void> cancel() => _cancel();
}

/// MQTT live-data service for publish and periodic telemetry workflows.
class LiveData {
  /// Creates a live-data service.
  LiveData({
    required String mqttHost,
    required int mqttPort,
    required bool mqttUseTls,
    required AccessTokenProvider authProvider,
    BackoffStrategy? backoffStrategy,
    DelayFn? delay,
    LiveDataTransportFactory? transportFactory,
    DateTime Function()? now,
    PeriodicTimerFactory? timerFactory,
  }) : _mqttHost = mqttHost,
       _mqttPort = mqttPort,
       _mqttUseTls = mqttUseTls,
       _authProvider = authProvider,
       _backoffStrategy = backoffStrategy ?? const FixedDelayBackoffStrategy(),
       _delay = delay ?? Future<void>.delayed,
       _now = now ?? DateTime.now,
       _timerFactory = timerFactory ?? _systemPeriodicTimerFactory,
       _transport = (transportFactory ?? _DefaultLiveDataTransport.new)();

  final String _mqttHost;
  final int _mqttPort;
  final bool _mqttUseTls;
  final AccessTokenProvider _authProvider;
  final BackoffStrategy _backoffStrategy;
  final DelayFn _delay;
  final DateTime Function() _now;
  final PeriodicTimerFactory _timerFactory;

  late LiveDataTransport _transport;

  Future<bool>? _connectFuture;
  bool _disconnectRequested = false;
  final ValueNotifier<bool> _isConnected = ValueNotifier<bool>(false);

  int _nextRegistrationId = 0;
  final Map<int, _RegistrationRecord> _registrations =
      <int, _RegistrationRecord>{};

  /// Observable connection state.
  ValueListenable<bool> get isConnected => _isConnected;

  /// Opens an MQTT connection.
  Future<bool> connect() {
    _disconnectRequested = false;
    final existing = _connectFuture;
    if (existing != null) {
      return existing;
    }

    final connectFuture = _connectWithRetry();
    _connectFuture = connectFuture.whenComplete(() {
      _connectFuture = null;
    });
    return _connectFuture!;
  }

  /// Closes the MQTT connection and pauses all periodic registrations.
  Future<void> disconnect() async {
    _disconnectRequested = true;
    _pauseActiveRegistrations();
    _isConnected.value = false;
    await _transport.disconnect();
  }

  /// Publishes JSON to a topic.
  ///
  /// Returns `true` when publish succeeds, otherwise `false`.
  Future<bool> publishJson(
    String topic,
    Map<String, dynamic> payload, {
    bool retained = false,
  }) async {
    _validateTopic(topic);
    final serializedPayload = _serializePayload(payload);

    if (!_isConnected.value) {
      return false;
    }

    try {
      return await _transport.publish(
        topic: topic,
        payload: serializedPayload,
        retained: retained,
      );
    } catch (_) {
      return false;
    }
  }

  /// Registers a generic periodic JSON publisher.
  LiveDataRegistration registerJsonBroadcast({
    required String topic,
    required LiveDataPayloadProvider payloadProvider,
    Duration interval = const Duration(seconds: 15),
    bool retained = false,
  }) {
    _validateTopic(topic);
    if (interval <= Duration.zero) {
      throw SpokeZoneException(
        code: SpokeZoneErrorCode.validationError,
        message: 'Interval must be greater than zero',
      );
    }

    final id = _nextRegistrationId++;
    final statusNotifier = ValueNotifier<LiveDataRegistrationStatus>(
      const LiveDataRegistrationStatus(
        state: LiveDataRegistrationState.idle,
        lastSuccessAt: null,
        consecutiveFailures: 0,
      ),
    );

    _registrations[id] = _RegistrationRecord(
      topic: topic,
      payloadProvider: payloadProvider,
      interval: interval,
      retained: retained,
      statusNotifier: statusNotifier,
    );

    if (_isConnected.value) {
      _startRegistration(id);
    }

    return LiveDataRegistration._(
      () => _cancelRegistration(id),
      statusNotifier,
    );
  }

  /// Registers periodic location broadcasts using the fixed SDK topic.
  LiveDataRegistration registerLocationBroadcast({
    required String deviceId,
    required Future<Coordinates?> Function() coordinatesProvider,
    Duration interval = const Duration(seconds: 15),
    bool retained = false,
  }) {
    _validateDeviceId(deviceId);
    return registerJsonBroadcast(
      topic: 'mrs/d/$deviceId/mon/location',
      interval: interval,
      retained: retained,
      payloadProvider: () async {
        final coordinates = await coordinatesProvider();
        if (coordinates == null) {
          return null;
        }
        return <String, dynamic>{
          'lat': coordinates.latitude,
          'lon': coordinates.longitude,
        };
      },
    );
  }

  /// Registers periodic software-version broadcasts using the fixed SDK topic.
  LiveDataRegistration registerSoftwareVersionsBroadcast({
    required String deviceId,
    required Future<Map<String, String>?> Function() versionsProvider,
    Duration interval = const Duration(seconds: 60),
    bool retained = false,
  }) {
    _validateDeviceId(deviceId);
    return registerJsonBroadcast(
      topic: 'mrs/d/$deviceId/mon/versions',
      interval: interval,
      retained: retained,
      payloadProvider: () async {
        final versions = await versionsProvider();
        if (versions == null) {
          return null;
        }
        return Map<String, dynamic>.from(versions);
      },
    );
  }

  Future<bool> _connectWithRetry() async {
    var retryNumber = 0;

    while (!_disconnectRequested) {
      final token = await _authProvider.getAccessToken();

      try {
        await _transport.connect(
          host: _mqttHost,
          port: _mqttPort,
          useTls: _mqttUseTls,
          accessToken: token,
        );
        _isConnected.value = true;
        _resumeRegistrations();
        return true;
      } catch (_) {
        _isConnected.value = false;
        retryNumber += 1;
        final wait = _backoffStrategy.delayForRetry(retryNumber);
        if (wait == null) {
          return false;
        }
        await _delay(wait);
      }
    }

    _isConnected.value = false;
    return false;
  }

  void _resumeRegistrations() {
    for (final id in _registrations.keys) {
      _startRegistration(id);
    }
  }

  void _pauseActiveRegistrations() {
    for (final record in _registrations.values) {
      record.timer?.cancel();
      record.timer = null;
    }
  }

  Future<void> _cancelRegistration(int id) async {
    final record = _registrations[id];
    if (record == null) {
      return;
    }

    record.timer?.cancel();
    record.timer = null;
    record.canceled = true;
    record.statusNotifier.value = LiveDataRegistrationStatus(
      state: LiveDataRegistrationState.canceled,
      lastSuccessAt: record.statusNotifier.value.lastSuccessAt,
      consecutiveFailures: record.statusNotifier.value.consecutiveFailures,
    );
  }

  void _startRegistration(int id) {
    final record = _registrations[id];
    if (record == null || record.canceled || record.timer != null) {
      return;
    }

    record.timer = _timerFactory(record.interval, () {
      unawaited(_runRegistrationTick(id));
    });
  }

  Future<void> _runRegistrationTick(int id) async {
    final record = _registrations[id];
    if (record == null || record.canceled || !_isConnected.value) {
      return;
    }

    if (record.isPublishing) {
      return;
    }
    record.isPublishing = true;

    try {
      final payload = await record.payloadProvider();
      if (payload == null) {
        return;
      }

      final success = await publishJson(
        record.topic,
        payload,
        retained: record.retained,
      );
      if (record.canceled) {
        return;
      }

      if (success) {
        record.statusNotifier.value = LiveDataRegistrationStatus(
          state: LiveDataRegistrationState.running,
          lastSuccessAt: _now(),
          consecutiveFailures: 0,
        );
      } else {
        final priorFailures = record.statusNotifier.value.consecutiveFailures;
        record.statusNotifier.value = LiveDataRegistrationStatus(
          state: LiveDataRegistrationState.failed,
          lastSuccessAt: record.statusNotifier.value.lastSuccessAt,
          consecutiveFailures: priorFailures + 1,
        );
      }
    } catch (_) {
      if (!record.canceled) {
        final priorFailures = record.statusNotifier.value.consecutiveFailures;
        record.statusNotifier.value = LiveDataRegistrationStatus(
          state: LiveDataRegistrationState.failed,
          lastSuccessAt: record.statusNotifier.value.lastSuccessAt,
          consecutiveFailures: priorFailures + 1,
        );
      }
    } finally {
      record.isPublishing = false;
    }
  }

  void _validateTopic(String topic) {
    if (topic.trim().isEmpty) {
      throw SpokeZoneException(
        code: SpokeZoneErrorCode.validationError,
        message: 'Topic must not be empty',
      );
    }
  }

  void _validateDeviceId(String deviceId) {
    if (deviceId.trim().isEmpty) {
      throw SpokeZoneException(
        code: SpokeZoneErrorCode.validationError,
        message: 'Device id must not be empty',
      );
    }
  }

  String _serializePayload(Map<String, dynamic> payload) {
    try {
      return jsonEncode(payload);
    } catch (_) {
      throw SpokeZoneException(
        code: SpokeZoneErrorCode.validationError,
        message: 'Payload must be JSON-encodable',
      );
    }
  }
}

class _RegistrationRecord {
  _RegistrationRecord({
    required this.topic,
    required this.payloadProvider,
    required this.interval,
    required this.retained,
    required this.statusNotifier,
  });

  final String topic;
  final LiveDataPayloadProvider payloadProvider;
  final Duration interval;
  final bool retained;
  final ValueNotifier<LiveDataRegistrationStatus> statusNotifier;

  bool canceled = false;
  bool isPublishing = false;
  PeriodicTimer? timer;
}

class _SystemPeriodicTimer implements PeriodicTimer {
  _SystemPeriodicTimer(this._timer);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

PeriodicTimer _systemPeriodicTimerFactory(
  Duration interval,
  void Function() onTick,
) {
  return _SystemPeriodicTimer(Timer.periodic(interval, (_) => onTick()));
}

class _DefaultLiveDataTransport implements LiveDataTransport {
  bool _connected = false;

  @override
  Future<void> connect({
    required String host,
    required int port,
    required bool useTls,
    required String accessToken,
  }) async {
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<bool> publish({
    required String topic,
    required String payload,
    required bool retained,
  }) async {
    return _connected;
  }
}
