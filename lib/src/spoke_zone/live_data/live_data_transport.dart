part of '../live_data.dart';

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
