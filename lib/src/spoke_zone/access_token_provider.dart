/// Contract for supplying the current access token used by API requests.
abstract interface class AccessTokenProvider {
  /// Returns a usable access token, performing login/refresh when needed.
  Future<String> getAccessToken();
}

/// Access token provider that can invalidate its cached token.
abstract interface class InvalidatableAccessTokenProvider
    implements AccessTokenProvider {
  /// Invalidates the cached token so the next read triggers refresh/login.
  void invalidateAccessToken();
}
