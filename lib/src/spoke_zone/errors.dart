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
  SpokeZoneException({
    required this.code,
    required this.message,
    this.endpoint,
    this.httpStatus,
    this.responseSnippet,
    this.retryAttempt,
    this.retryAfter,
  });

  final SpokeZoneErrorCode code;
  final String message;
  final String? endpoint;
  final int? httpStatus;
  final String? responseSnippet;
  final int? retryAttempt;
  final Duration? retryAfter;
}
