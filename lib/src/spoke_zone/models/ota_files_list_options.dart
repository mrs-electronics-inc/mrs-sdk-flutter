/// Query options for `otaFiles.list`.
class OtaFilesListOptions {
  /// Creates OTA list query options.
  const OtaFilesListOptions({
    this.searchTerm,
    this.searchFields,
    this.sort,
    this.sortOrder,
    this.limit = 50,
    this.offset = 0,
  });

  /// Search term.
  final String? searchTerm;

  /// Comma-separated searchable fields.
  final String? searchFields;

  /// Sort field.
  final String? sort;

  /// Sort order (for example `asc` or `desc`).
  final String? sortOrder;

  /// Page size. Defaults to `50`.
  final int limit;

  /// Row offset. Defaults to `0`.
  final int offset;
}
