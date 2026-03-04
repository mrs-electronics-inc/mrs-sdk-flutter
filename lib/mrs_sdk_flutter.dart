/// The official Flutter package for integrating mobile apps with MRS Electronic
/// products and services.
///
/// The [SpokeZone] class is the main entry point for integrating with
/// [Spoke.Zone](https://spoke.zone) from Flutter apps.
///
/// Create a [SpokeZone] object with [SpokeZoneConfig], then use its client
/// surfaces:
/// - [DevicesClient]
/// - [OtaFilesClient]
/// - [DataFilesClient]
/// - [LiveData]
library;

export 'src/spoke_zone/config.dart';
export 'src/spoke_zone/errors.dart';
export 'src/spoke_zone/models/callbacks.dart';
export 'src/spoke_zone/models/coordinates.dart';
export 'src/spoke_zone/models/device_details.dart';
export 'src/spoke_zone/models/ota_file.dart';
export 'src/spoke_zone/models/ota_files_list_options.dart';
export 'src/spoke_zone/live_data.dart';
export 'src/spoke_zone/retry.dart';
export 'src/spoke_zone/spoke_zone.dart';
