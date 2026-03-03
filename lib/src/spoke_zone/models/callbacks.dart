typedef AsyncStringCallback = Future<String> Function();

class DeviceAuthCallbacks {
  const DeviceAuthCallbacks({
    required this.cpuId,
    required this.uuid,
    required this.deviceId,
    required this.initialDeviceToken,
  });

  final AsyncStringCallback cpuId;
  final AsyncStringCallback uuid;
  final AsyncStringCallback deviceId;
  final AsyncStringCallback initialDeviceToken;
}

class UserAuthCallbacks {
  const UserAuthCallbacks({required this.username, required this.password});

  final AsyncStringCallback username;
  final AsyncStringCallback password;
}
