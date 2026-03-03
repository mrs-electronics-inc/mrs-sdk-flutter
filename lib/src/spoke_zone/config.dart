import 'models.dart';

enum SpokeZoneAuthMode { device, user }

class SpokeZoneConfig {
  SpokeZoneConfig.device({
    Uri? baseUri,
    required this.deviceAuth,
  })  : baseUri = baseUri ?? Uri.parse('https://api.spoke.zone'),
        authMode = SpokeZoneAuthMode.device,
        userAuth = null;

  SpokeZoneConfig.user({
    Uri? baseUri,
    required this.userAuth,
  })  : baseUri = baseUri ?? Uri.parse('https://api.spoke.zone'),
        authMode = SpokeZoneAuthMode.user,
        deviceAuth = null;

  final Uri baseUri;
  final SpokeZoneAuthMode authMode;
  final DeviceAuthCallbacks? deviceAuth;
  final UserAuthCallbacks? userAuth;
}
