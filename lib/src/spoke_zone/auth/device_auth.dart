import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../access_token_provider.dart';
import '../http_helpers.dart';
import '../models/callbacks.dart';
import '../retry.dart';
import 'cached_access_token_provider.dart';

/// Device authentication provider for Spoke.Zone.
class DeviceAuth extends CachedAccessTokenProvider
    implements InvalidatableAccessTokenProvider {
  /// Creates a device auth provider.
  DeviceAuth({
    required this.baseUri,
    required this.callbacks,
    required this.httpClient,
    BackoffStrategy? backoffStrategy,
    DelayFn? delay,
  }) : _backoffStrategy = backoffStrategy ?? const FixedDelayBackoffStrategy(),
       _delay = delay ?? Future<void>.delayed;

  /// Base Spoke.Zone API URI used for device login requests.
  final Uri baseUri;
  final DeviceAuthCallbacks callbacks;
  final http.Client httpClient;
  final BackoffStrategy _backoffStrategy;
  final DelayFn _delay;
  String? _cachedToken;

  static const Duration _proactiveRefreshWindow = Duration(hours: 12);

  /// Performs `/loginDevice` and returns the current access token.
  @override
  Future<String> login() async {
    final seedToken = await callbacks.initialDeviceToken();
    final response = await sendWithRetry(
      () async {
        final req = http.Request('POST', baseUri.replace(path: '/loginDevice'));
        req.headers['content-type'] = 'application/json';
        req.body = jsonEncode({
          'token': seedToken,
          'cpu_id': await callbacks.cpuId(),
          'uuid': await callbacks.uuid(),
        });
        return req;
      },
      (request) => httpClient.send(request),
      _backoffStrategy,
      _delay,
    );

    if (response.statusCode == 201) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      cacheToken(body['token'] as String);
    } else {
      cacheToken(seedToken);
    }
    return _cachedToken!;
  }

  @override
  Future<String> getAccessToken() async {
    var token = _cachedToken ??= await login();
    if (_shouldRefreshProactively(token)) {
      invalidateAccessToken();
      token = await login();
    }
    return token;
  }

  @override
  void invalidateAccessToken() {
    _cachedToken = null;
  }

  @override
  void cacheToken(String token) {
    final previousToken = _cachedToken;
    _cachedToken = token;
    final onTokenUpdated = callbacks.onTokenUpdated;
    if (previousToken != token && onTokenUpdated != null) {
      unawaited(Future<void>.sync(() => onTokenUpdated(token)));
    }
  }

  bool _shouldRefreshProactively(String token) {
    final expiry = _extractJwtExpiry(token);
    if (expiry == null) {
      return false;
    }
    return DateTime.now().toUtc().add(_proactiveRefreshWindow).isAfter(expiry);
  }

  DateTime? _extractJwtExpiry(String token) {
    final parts = token.split('.');
    if (parts.length < 2) {
      return null;
    }
    try {
      final payload = utf8.decode(base64Url.decode(base64.normalize(parts[1])));
      final body = jsonDecode(payload) as Map<String, dynamic>;
      final expRaw = body['exp'];
      if (expRaw is! num) {
        return null;
      }
      return DateTime.fromMillisecondsSinceEpoch(
        (expRaw * 1000).toInt(),
        isUtc: true,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}
