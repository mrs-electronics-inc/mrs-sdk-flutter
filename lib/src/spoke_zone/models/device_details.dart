import 'coordinates.dart';

/// Device details returned by `devices.get`.
class DeviceDetails {
  /// Creates a device details model.
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

  /// Device numeric ID.
  final int id;

  /// Device identifier string.
  final String identifier;

  /// Device serial number.
  final String serialNumber;

  /// Model numeric ID.
  final int modelId;

  /// Model display name.
  final String modelName;

  /// Last online timestamp, or `null` when missing/invalid.
  final DateTime? lastOnline;

  /// Last known location, or `null` when unavailable.
  final Coordinates? lastLocation;

  /// Module-to-version map, empty when unavailable.
  final Map<String, String> softwareVersions;
}
