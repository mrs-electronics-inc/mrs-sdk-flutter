import 'models/callbacks.dart';
import 'retry.dart';

/// Auth mode used by a [SpokeZoneConfig].
enum SpokeZoneAuthMode { device, user }

/// Configuration for creating a [SpokeZone] client.
class SpokeZoneConfig {
  /// Creates a device-authenticated configuration.
  SpokeZoneConfig.device({
    Uri? baseUri,
    required this.deviceAuth,
    this.mqttHost = 'io.spoke.zone',
    this.mqttPort = 8883,
    this.mqttUseTls = true,
    this.apiBackoffStrategy = const FixedDelayBackoffStrategy(),
    this.liveDataBackoffStrategy = const FixedDelayBackoffStrategy(
      delays: [
        Duration(seconds: 5),
        Duration(seconds: 15),
        Duration(seconds: 30),
        Duration(seconds: 60),
        Duration(seconds: 120),
        Duration(seconds: 300),
      ],
      repeatLastDelay: true,
    ),
  }) : baseUri = baseUri ?? Uri.parse('https://api.spoke.zone'),
       authMode = SpokeZoneAuthMode.device,
       userAuth = null;

  /// Creates a user-authenticated configuration.
  SpokeZoneConfig.user({
    Uri? baseUri,
    required this.userAuth,
    this.mqttHost = 'io.spoke.zone',
    this.mqttPort = 8883,
    this.mqttUseTls = true,
    this.apiBackoffStrategy = const FixedDelayBackoffStrategy(),
    this.liveDataBackoffStrategy = const FixedDelayBackoffStrategy(
      delays: [
        Duration(seconds: 5),
        Duration(seconds: 15),
        Duration(seconds: 30),
        Duration(seconds: 60),
        Duration(seconds: 120),
        Duration(seconds: 300),
      ],
      repeatLastDelay: true,
    ),
  }) : baseUri = baseUri ?? Uri.parse('https://api.spoke.zone'),
       authMode = SpokeZoneAuthMode.user,
       deviceAuth = null;

  /// Base URI used for all auth and API requests.
  final Uri baseUri;

  /// Active auth mode for this configuration.
  final SpokeZoneAuthMode authMode;

  /// Device callbacks when [authMode] is [SpokeZoneAuthMode.device].
  final DeviceAuthCallbacks? deviceAuth;

  /// User callbacks when [authMode] is [SpokeZoneAuthMode.user].
  final UserAuthCallbacks? userAuth;

  /// MQTT broker host used for live-data publishing.
  final String mqttHost;

  /// MQTT broker port used for live-data publishing.
  final int mqttPort;

  /// Whether MQTT transport uses TLS.
  final bool mqttUseTls;

  /// Retry/backoff strategy used by auth and all HTTP endpoint clients.
  final BackoffStrategy apiBackoffStrategy;

  /// Retry/backoff strategy used by MQTT live-data reconnect.
  final BackoffStrategy liveDataBackoffStrategy;
}
