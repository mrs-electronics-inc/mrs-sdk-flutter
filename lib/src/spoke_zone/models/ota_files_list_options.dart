class OtaFilesListOptions {
  const OtaFilesListOptions({
    this.searchTerm,
    this.searchFields,
    this.sort,
    this.sortOrder,
    this.limit = 50,
    this.offset = 0,
  });

  final String? searchTerm;
  final String? searchFields;
  final String? sort;
  final String? sortOrder;
  final int limit;
  final int offset;
}
