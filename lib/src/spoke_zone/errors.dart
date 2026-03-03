/// Stable SDK error codes surfaced by public APIs.
enum SpokeZoneErrorCode {
  /// Request is not authenticated (`401`).
  unauthorized,

  /// Authenticated caller is not allowed (`403`).
  forbidden,

  /// Requested resource does not exist (`404`).
  notFound,

  /// Request was rate-limited (`429`).
  rateLimited,

  /// Server-side failure (`5xx`).
  serverError,

  /// Network or transport failure.
  networkError,

  /// Client-side validation failed before request dispatch.
  validationError,

  /// Selected auth mode cannot satisfy this operation.
  unsupportedAuthMode,

  /// Retry policy was exhausted.
  retryLimitReached,

  /// Any non-classified failure.
  unknown,
}

/// Typed exception used by all public SDK APIs.
class SpokeZoneException implements Exception {
  /// Creates a typed SDK exception.
  SpokeZoneException({
    required this.code,
    required this.message,
    this.endpoint,
    this.httpStatus,
    this.responseSnippet,
    this.retryAttempt,
    this.retryAfter,
  });

  /// Stable SDK error code.
  final SpokeZoneErrorCode code;

  /// Human-readable error message.
  final String message;

  /// Endpoint path related to the failure, when available.
  final String? endpoint;

  /// HTTP status related to the failure, when available.
  final int? httpStatus;

  /// Bounded response snippet for diagnostics, when available.
  final String? responseSnippet;

  /// Retry attempt index at failure time, when applicable.
  final int? retryAttempt;

  /// Last computed retry delay, when applicable.
  final Duration? retryAfter;
}
