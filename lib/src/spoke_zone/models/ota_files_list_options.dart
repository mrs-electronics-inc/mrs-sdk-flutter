/// Query options for `otaFiles.list`.
class OtaFilesListOptions {
  /// Creates OTA list query options.
  const OtaFilesListOptions({
    this.searchTerm,
    this.searchFields,
    this.sort,
    this.sortOrder,
    this.module,
    this.isActive,
    this.limit = 50,
    this.offset = 0,
  });

  /// Search term filter.
  final String? searchTerm;

  /// Comma-separated fields to search.
  final String? searchFields;

  /// Field used for sorting.
  final String? sort;

  /// Sort direction (for example `asc` or `desc`).
  final String? sortOrder;

  /// Module filter.
  final String? module;

  /// Active-status filter.
  final bool? isActive;

  /// Maximum number of results returned. Defaults to `50`.
  final int limit;

  /// Result offset. Defaults to `0`.
  final int offset;
}
