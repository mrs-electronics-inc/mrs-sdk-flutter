import 'dart:convert';

import 'package:http/http.dart' as http;

import '../http_helpers.dart';
import '../models/callbacks.dart';
import '../retry.dart';
import 'cached_access_token_provider.dart';

class UserAuth extends CachedAccessTokenProvider {
  UserAuth({
    required this.baseUri,
    required this.callbacks,
    required this.httpClient,
    BackoffStrategy? backoffStrategy,
    DelayFn? delay,
  })  : _backoffStrategy = backoffStrategy ?? const FixedDelayBackoffStrategy(),
        _delay = delay ?? Future<void>.delayed;

  final Uri baseUri;
  final UserAuthCallbacks callbacks;
  final http.Client httpClient;
  final BackoffStrategy _backoffStrategy;
  final DelayFn _delay;

  @override
  Future<String> login() async {
    final response = await sendWithRetry(() async {
      final req = http.Request('POST', baseUri.replace(path: '/login'));
      req.headers['content-type'] = 'application/json';
      req.body = jsonEncode({
        'username': await callbacks.username(),
        'password': await callbacks.password(),
      });
      return req;
    }, (request) => httpClient.send(request), _backoffStrategy, _delay);
    final body = decodeJsonObject(response.body);
    cacheToken(body['token'] as String);
    return getAccessToken();
  }
}
