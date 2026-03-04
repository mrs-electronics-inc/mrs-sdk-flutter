import 'dart:convert';

import 'package:http/http.dart' as http;

import 'access_token_provider.dart';
import 'errors.dart';
import 'retry.dart';

Future<http.Response> sendWithRetry(
  Future<http.Request> Function() buildRequest,
  Future<http.StreamedResponse> Function(http.Request request) send,
  BackoffStrategy backoffStrategy,
  DelayFn delay,
) async {
  var retryNumber = 0;
  while (true) {
    try {
      final request = await buildRequest();
      final response = await http.Response.fromStream(await send(request));
      final endpoint = request.url.path;
      if (!isError(response.statusCode)) {
        return response;
      }
      if (isRetryable(response.statusCode)) {
        retryNumber += 1;
        final wait = backoffStrategy.delayForRetry(retryNumber);
        if (wait != null) {
          await delay(wait);
          continue;
        }
        throw retryLimitError(
          endpoint: endpoint,
          httpStatus: response.statusCode,
          responseBody: response.body,
          retryAttempt: retryNumber,
          retryAfter: wait,
        );
      }

      throw statusError(
        endpoint: endpoint,
        statusCode: response.statusCode,
        responseBody: response.body,
        messagePrefix: 'Auth request failed',
      );
    } on http.ClientException {
      retryNumber += 1;
      final wait = backoffStrategy.delayForRetry(retryNumber);
      if (wait != null) {
        await delay(wait);
        continue;
      }
      throw retryLimitError(retryAttempt: retryNumber, retryAfter: wait);
    }
  }
}

Future<http.Response> sendAuthorizedJsonWithRetry({
  required http.Client httpClient,
  required AccessTokenProvider auth,
  required http.Request Function(String token) requestBuilder,
  required BackoffStrategy backoffStrategy,
  required DelayFn delay,
}) async {
  var token = await auth.getAccessToken();
  var retryNumber = 0;
  var retriedAfterUnauthorized = false;

  while (true) {
    try {
      final request = requestBuilder(token);
      final response = await http.Response.fromStream(
        await httpClient.send(request),
      );
      final endpoint = request.url.path;
      if (response.statusCode < 400) {
        return response;
      }
      if (response.statusCode == 401 &&
          !retriedAfterUnauthorized &&
          auth is InvalidatableAccessTokenProvider) {
        retriedAfterUnauthorized = true;
        auth.invalidateAccessToken();
        token = await auth.getAccessToken();
        continue;
      }
      if (isRetryable(response.statusCode)) {
        retryNumber += 1;
        final wait = backoffStrategy.delayForRetry(retryNumber);
        if (wait != null) {
          await delay(wait);
          continue;
        }
        throw retryLimitError(
          endpoint: endpoint,
          httpStatus: response.statusCode,
          responseBody: response.body,
          retryAttempt: retryNumber,
          retryAfter: wait,
        );
      }
      throw statusError(
        endpoint: endpoint,
        statusCode: response.statusCode,
        responseBody: response.body,
        messagePrefix: 'Request failed',
      );
    } on http.ClientException {
      retryNumber += 1;
      final wait = backoffStrategy.delayForRetry(retryNumber);
      if (wait != null) {
        await delay(wait);
        continue;
      }
      throw retryLimitError(retryAttempt: retryNumber, retryAfter: wait);
    }
  }
}

bool isError(int statusCode) => statusCode >= 400;
bool isRetryable(int statusCode) => statusCode == 429 || statusCode >= 500;

SpokeZoneErrorCode mapStatus(int statusCode) {
  return switch (statusCode) {
    401 => SpokeZoneErrorCode.unauthorized,
    403 => SpokeZoneErrorCode.forbidden,
    404 => SpokeZoneErrorCode.notFound,
    429 => SpokeZoneErrorCode.rateLimited,
    >= 500 => SpokeZoneErrorCode.serverError,
    _ => SpokeZoneErrorCode.unknown,
  };
}

Map<String, dynamic> decodeJsonObject(String body) {
  return jsonDecode(body) as Map<String, dynamic>;
}

List<dynamic> decodeJsonList(String body) {
  return jsonDecode(body) as List<dynamic>;
}

String snippet(String body) {
  if (body.length <= 200) {
    return body;
  }
  return body.substring(0, 200);
}

SpokeZoneException retryLimitError({
  String? endpoint,
  int? httpStatus,
  String? responseBody,
  required int retryAttempt,
  required Duration? retryAfter,
}) {
  return SpokeZoneException(
    code: SpokeZoneErrorCode.retryLimitReached,
    message: 'Retry limit reached',
    endpoint: endpoint,
    httpStatus: httpStatus,
    responseSnippet: responseBody == null ? null : snippet(responseBody),
    retryAttempt: retryAttempt,
    retryAfter: retryAfter,
  );
}

SpokeZoneException statusError({
  required String endpoint,
  required int statusCode,
  required String responseBody,
  required String messagePrefix,
}) {
  return SpokeZoneException(
    code: mapStatus(statusCode),
    message: '$messagePrefix with status $statusCode',
    endpoint: endpoint,
    httpStatus: statusCode,
    responseSnippet: snippet(responseBody),
  );
}
