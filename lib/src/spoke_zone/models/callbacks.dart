/// Async string callback used by auth providers.
typedef AsyncStringCallback = Future<String> Function();

/// Callback set required for device authentication.
class DeviceAuthCallbacks {
  /// Creates device auth callbacks.
  const DeviceAuthCallbacks({
    required this.cpuId,
    required this.uuid,
    required this.deviceId,
    required this.initialDeviceToken,
  });

  /// Resolves the device CPU identifier.
  final AsyncStringCallback cpuId;

  /// Resolves the device UUID.
  final AsyncStringCallback uuid;

  /// Resolves the platform device identifier.
  final AsyncStringCallback deviceId;

  /// Resolves the initial device token used by `/loginDevice`.
  final AsyncStringCallback initialDeviceToken;
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
