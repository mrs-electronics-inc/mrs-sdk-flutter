import 'package:http/http.dart' as http;

import 'auth/device_auth.dart';
import 'auth/user_auth.dart';
import 'access_token_provider.dart';
import 'clients/data_files_client.dart';
import 'clients/devices_client.dart';
import 'clients/ota_files_client.dart';
import 'config.dart';
import 'retry.dart';

export 'access_token_provider.dart';
export 'auth/device_auth.dart';
export 'auth/user_auth.dart';
export 'clients/data_files_client.dart';
export 'clients/devices_client.dart';
export 'clients/ota_files_client.dart';

/// Root Spoke.Zone SDK entry point.
///
/// Use [SpokeZoneConfig.device] or [SpokeZoneConfig.user] to select auth mode.
class SpokeZone {
  /// Creates a Spoke.Zone client.
  SpokeZone({
    required this.config,
    required this.httpClient,
    BackoffStrategy? backoffStrategy,
    DelayFn? delay,
  })  : _backoffStrategy = backoffStrategy ?? const FixedDelayBackoffStrategy(),
        _delay = delay ?? Future<void>.delayed {
    final auth = _buildAuthProvider(config: config, httpClient: httpClient);

    devices = DevicesClient(
      httpClient: httpClient,
      baseUri: config.baseUri,
      auth: auth,
      backoffStrategy: _backoffStrategy,
      delay: _delay,
    );
    otaFiles = OtaFilesClient(
      httpClient: httpClient,
      baseUri: config.baseUri,
      auth: auth,
      backoffStrategy: _backoffStrategy,
      delay: _delay,
    );
    dataFiles = DataFilesClient(
      httpClient: httpClient,
      baseUri: config.baseUri,
      auth: auth,
      backoffStrategy: _backoffStrategy,
      delay: _delay,
    );
  }

  final SpokeZoneConfig config;
  final http.Client httpClient;
  final BackoffStrategy _backoffStrategy;
  final DelayFn _delay;

  /// Device endpoints.
  late final DevicesClient devices;

  /// OTA endpoints.
  late final OtaFilesClient otaFiles;

  /// Data file endpoints.
  late final DataFilesClient dataFiles;

  AccessTokenProvider _buildAuthProvider({
    required SpokeZoneConfig config,
    required http.Client httpClient,
  }) {
    return switch (config.authMode) {
      SpokeZoneAuthMode.device => DeviceAuth(
          baseUri: config.baseUri,
          callbacks: config.deviceAuth!,
          httpClient: httpClient,
          backoffStrategy: _backoffStrategy,
          delay: _delay,
        ),
      SpokeZoneAuthMode.user => UserAuth(
          baseUri: config.baseUri,
          callbacks: config.userAuth!,
          httpClient: httpClient,
          backoffStrategy: _backoffStrategy,
          delay: _delay,
        ),
    };
  }
}
