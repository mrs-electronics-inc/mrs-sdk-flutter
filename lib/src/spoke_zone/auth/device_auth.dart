import 'dart:convert';

import 'package:http/http.dart' as http;

import '../http_helpers.dart';
import '../models/callbacks.dart';
import '../retry.dart';
import 'cached_access_token_provider.dart';

/// Device authentication provider for Spoke.Zone.
class DeviceAuth extends CachedAccessTokenProvider {
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
    return getAccessToken();
  }
}
