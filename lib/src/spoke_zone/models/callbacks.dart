import 'dart:async';

/// Async string callback used by auth providers.
typedef AsyncStringCallback = Future<String> Function();

/// Async integer callback used by auth providers for numeric device identifiers.
typedef AsyncIntCallback = Future<int> Function();

/// Callback invoked when device auth updates the active token.
typedef TokenUpdatedCallback = FutureOr<void> Function(String token);

/// Callback set required for device authentication.
class DeviceAuthCallbacks {
  /// Creates device auth callbacks.
  const DeviceAuthCallbacks({
    required this.cpuId,
    required this.uuid,
    required this.deviceId,
    required this.initialDeviceToken,
    this.onTokenUpdated,
  });

  /// Resolves the device CPU identifier.
  final AsyncStringCallback cpuId;

  /// Resolves the device UUID.
  final AsyncStringCallback uuid;

  /// Resolves the numeric platform device identifier.
  final AsyncIntCallback deviceId;

  /// Resolves the initial device token used by `/loginDevice`.
  final AsyncStringCallback initialDeviceToken;

  /// Called when the active token changes.
  final TokenUpdatedCallback? onTokenUpdated;
}

/// Callback set required for user authentication.
class UserAuthCallbacks {
  /// Creates user auth callbacks.
  const UserAuthCallbacks({required this.username, required this.password});

  /// Resolves username for `/login`.
  final AsyncStringCallback username;

  /// Resolves password for `/login`.
  final AsyncStringCallback password;
}
