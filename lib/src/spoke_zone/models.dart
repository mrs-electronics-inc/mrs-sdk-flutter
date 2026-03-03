typedef AsyncStringCallback = Future<String> Function();

class Coordinates {
  const Coordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

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

class OtaFile {
  const OtaFile({
    required this.id,
    required this.modelId,
    required this.moduleId,
    required this.module,
    required this.version,
    required this.fileLocation,
    required this.isActive,
    required this.createdDate,
    required this.releaseNotes,
  });

  final int id;
  final int modelId;
  final int moduleId;
  final String module;
  final String version;
  final String fileLocation;
  final bool isActive;
  final String createdDate;
  final String releaseNotes;
}

class DeviceDetails {
  const DeviceDetails({
    required this.id,
    required this.identifier,
    required this.serialNumber,
    required this.modelId,
    required this.modelName,
    required this.lastOnline,
    required this.lastLocation,
    required this.softwareVersions,
  });

  final int id;
  final String identifier;
  final String serialNumber;
  final int modelId;
  final String modelName;
  final DateTime? lastOnline;
  final Coordinates? lastLocation;
  final Map<String, String> softwareVersions;
}

class OtaFilesListOptions {
  const OtaFilesListOptions({
    this.searchTerm,
    this.searchFields,
    this.sort,
    this.sortOrder,
    this.limit = 50,
    this.offset = 0,
  });

  final String? searchTerm;
  final String? searchFields;
  final String? sort;
  final String? sortOrder;
  final int limit;
  final int offset;
}
