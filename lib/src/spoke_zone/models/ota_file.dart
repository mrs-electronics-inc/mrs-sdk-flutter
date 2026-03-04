/// OTA file metadata item returned by `otaFiles.list`.
class OtaFile {
  /// Creates OTA file metadata.
  const OtaFile({
    required this.id,
    required this.modelId,
    required this.moduleId,
    required this.module,
    required this.version,
    required this.fileLocation,
    required this.isActive,
    required this.createdDate,
    required this.releaseDate,
    required this.releaseNotes,
  });

  /// OTA file numeric ID.
  final int id;

  /// Associated model ID.
  final int modelId;

  /// Associated module ID.
  final int moduleId;

  /// Module name.
  final String module;

  /// Version string.
  final String version;

  /// Server file location.
  final String fileLocation;

  /// Active status flag.
  final bool isActive;

  /// Parsed creation date from API when present and valid.
  final DateTime? createdDate;

  /// Parsed release date from API when present and valid.
  final DateTime? releaseDate;

  /// Release notes text.
  final String releaseNotes;
}
