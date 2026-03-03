import 'package:http/http.dart' as http;

import 'auth/device_auth.dart';
import 'auth/user_auth.dart';
import 'access_token_provider.dart';
import 'clients/data_files_client.dart';
import 'clients/devices_client.dart';
import 'clients/ota_files_client.dart';
import 'config.dart';
import 'live_data.dart';
import 'retry.dart';

export 'access_token_provider.dart';
export 'auth/device_auth.dart';
export 'auth/user_auth.dart';
export 'clients/data_files_client.dart';
export 'clients/devices_client.dart';
export 'clients/ota_files_client.dart';
export 'live_data.dart';

/// Spoke.Zone Integration
///
/// Use [SpokeZoneConfig.device] or [SpokeZoneConfig.user] to select auth mode.
class SpokeZone {
  /// Creates a Spoke.Zone client.
  SpokeZone({
    required this.config,
    http.Client? httpClient,
    BackoffStrategy? backoffStrategy,
    DelayFn? delay,
    AccessTokenProvider? authProvider,
    LiveDataTransportFactory? liveDataTransportFactory,
    DateTime Function()? liveDataNow,
    PeriodicTimerFactory? liveDataTimerFactory,
  }) : httpClient = httpClient ?? http.Client(),
       _backoffStrategy = backoffStrategy ?? const FixedDelayBackoffStrategy(),
       _delay = delay ?? Future<void>.delayed {
    final auth =
        authProvider ??
        _buildAuthProvider(
          config: config,
          httpClient: this.httpClient,
          backoffStrategy: _backoffStrategy,
          delay: _delay,
        );
    _auth = auth;

    devices = DevicesClient(
      httpClient: this.httpClient,
      baseUri: config.baseUri,
      auth: auth,
      backoffStrategy: _backoffStrategy,
      delay: _delay,
    );
    otaFiles = OtaFilesClient(
      httpClient: this.httpClient,
      baseUri: config.baseUri,
      auth: auth,
      backoffStrategy: _backoffStrategy,
      delay: _delay,
    );
    dataFiles = DataFilesClient(
      httpClient: this.httpClient,
      baseUri: config.baseUri,
      auth: auth,
      backoffStrategy: _backoffStrategy,
      delay: _delay,
    );
    liveData = LiveData(
      mqttHost: config.mqttHost,
      mqttPort: config.mqttPort,
      mqttUseTls: config.mqttUseTls,
      authProvider: auth,
      backoffStrategy: _backoffStrategy,
      delay: _delay,
      transportFactory: liveDataTransportFactory,
      now: liveDataNow,
      timerFactory: liveDataTimerFactory,
    );
  }

  final SpokeZoneConfig config;
  final http.Client httpClient;
  final BackoffStrategy _backoffStrategy;
  final DelayFn _delay;
  late final AccessTokenProvider _auth;

  /// Device endpoints.
  late final DevicesClient devices;

  /// OTA endpoints.
  late final OtaFilesClient otaFiles;

  /// Data file endpoints.
  late final DataFilesClient dataFiles;

  /// MQTT live-data publishing.
  late final LiveData liveData;

  static AccessTokenProvider _buildAuthProvider({
    required SpokeZoneConfig config,
    required http.Client httpClient,
    required BackoffStrategy backoffStrategy,
    required DelayFn delay,
  }) {
    return switch (config.authMode) {
      SpokeZoneAuthMode.device => DeviceAuth(
        baseUri: config.baseUri,
        callbacks: config.deviceAuth!,
        httpClient: httpClient,
        backoffStrategy: backoffStrategy,
        delay: delay,
      ),
      SpokeZoneAuthMode.user => UserAuth(
        baseUri: config.baseUri,
        callbacks: config.userAuth!,
        httpClient: httpClient,
        backoffStrategy: backoffStrategy,
        delay: delay,
      ),
    };
  }
}
