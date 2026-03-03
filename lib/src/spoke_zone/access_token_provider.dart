/// Contract for supplying the current access token used by API requests.
abstract interface class AccessTokenProvider {
  /// Returns a usable access token, performing login/refresh when needed.
  Future<String> getAccessToken();
}
