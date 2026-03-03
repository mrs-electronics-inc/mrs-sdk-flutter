import '../access_token_provider.dart';

abstract class CachedAccessTokenProvider implements AccessTokenProvider {
  String? _token;

  Future<String> login();

  void cacheToken(String token) {
    _token = token;
  }

  @override
  Future<String> getAccessToken() async {
    if (_token != null) {
      return _token!;
    }
    return login();
  }
}
