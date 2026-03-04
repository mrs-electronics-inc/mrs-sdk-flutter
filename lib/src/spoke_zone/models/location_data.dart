/// Geographic location and movement data.
class LocationData {
  /// Creates location data.
  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.heading,
    required this.speed,
  });

  /// Latitude value.
  final double latitude;

  /// Longitude value.
  final double longitude;

  /// Heading in degrees in the range 0-360.
  final double heading;

  /// Ground speed in meters/second.
  final double speed;
}
