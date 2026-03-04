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
  MqttServerClient? _client;
  bool _connected = false;

  @override
  Future<void> connect({
    required String host,
    required int port,
    required bool useTls,
    required String accessToken,
  }) async {
    await disconnect();

    final client = MqttServerClient.withPort(
      host,
      _buildLiveDataClientIdentifier(),
      port,
    );
    client.secure = useTls;
    client.keepAlivePeriod = 20;
    client.setProtocolV311();

    final status = await client.connect('', accessToken);
    if (status?.state != mqtt.MqttConnectionState.connected) {
      client.disconnect();
      _connected = false;
      throw StateError('MQTT connection failed');
    }

    _client = client;
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _client?.disconnect();
    _client = null;
    _connected = false;
  }

  @override
  Future<bool> publish({
    required String topic,
    required String payload,
    required bool retained,
  }) async {
    if (!_connected || _client == null) {
      return false;
    }

    final builder = mqtt.MqttClientPayloadBuilder();
    builder.addString(payload);
    final encodedPayload = builder.payload;
    if (encodedPayload == null) {
      return false;
    }

    try {
      _client!.publishMessage(
        topic,
        mqtt.MqttQos.atLeastOnce,
        encodedPayload,
        retain: retained,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

String _buildLiveDataClientIdentifier() {
  final unixTimeMs = DateTime.now().millisecondsSinceEpoch;
  return 'mrs-live-$unixTimeMs';
}
