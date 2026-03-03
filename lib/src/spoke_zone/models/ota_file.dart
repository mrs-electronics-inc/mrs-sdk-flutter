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
