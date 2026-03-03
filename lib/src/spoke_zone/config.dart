import 'models/callbacks.dart';

/// Auth mode used by a [SpokeZoneConfig].
enum SpokeZoneAuthMode { device, user }

/// Configuration for creating a [SpokeZone] client.
class SpokeZoneConfig {
  /// Creates a device-authenticated configuration.
  SpokeZoneConfig.device({
    Uri? baseUri,
    required this.deviceAuth,
  })  : baseUri = baseUri ?? Uri.parse('https://api.spoke.zone'),
        authMode = SpokeZoneAuthMode.device,
        userAuth = null;

  /// Creates a user-authenticated configuration.
  SpokeZoneConfig.user({
    Uri? baseUri,
    required this.userAuth,
  })  : baseUri = baseUri ?? Uri.parse('https://api.spoke.zone'),
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
}
