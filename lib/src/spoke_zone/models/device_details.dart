import 'coordinates.dart';

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
