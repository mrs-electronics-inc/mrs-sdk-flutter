enum SpokeZoneErrorCode {
  unauthorized,
  forbidden,
  notFound,
  rateLimited,
  serverError,
  networkError,
  validationError,
  unsupportedAuthMode,
  retryLimitReached,
  unknown,
}

class SpokeZoneException implements Exception {
  SpokeZoneException({required this.code, required this.message});

  final SpokeZoneErrorCode code;
  final String message;
}
