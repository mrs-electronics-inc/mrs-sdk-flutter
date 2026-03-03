import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mrs_sdk_flutter/mrs_sdk_flutter.dart';

DeviceAuthCallbacks deviceCallbacks() {
  return DeviceAuthCallbacks(
    cpuId: () async => 'cpu-1',
    uuid: () async => 'uuid-1',
    deviceId: () async => 'device-1',
    initialDeviceToken: () async => 'initial-device-token',
  );
}

UserAuthCallbacks userCallbacks() {
  return UserAuthCallbacks(
    username: () async => 'user-a',
    password: () async => 'pw-a',
  );
}

class QueuedClient extends http.BaseClient {
  final Queue<Future<http.StreamedResponse> Function(http.BaseRequest)>
  _handlers = Queue<Future<http.StreamedResponse> Function(http.BaseRequest)>();
  final List<http.BaseRequest> requests = <http.BaseRequest>[];

  void enqueueJson(int statusCode, Object body) {
    _handlers.add((_) async {
      final encoded = utf8.encode(jsonEncode(body));
      return http.StreamedResponse(
        Stream<List<int>>.fromIterable(<List<int>>[encoded]),
        statusCode,
        headers: const {'content-type': 'application/json'},
      );
    });
  }

  void enqueueBytes(int statusCode, List<int> bytes) {
    _handlers.add(
      (_) async => http.StreamedResponse(
        Stream<List<int>>.fromIterable(<List<int>>[bytes]),
        statusCode,
      ),
    );
  }

  void enqueueException(Object error) {
    _handlers.add((_) async => throw error);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    if (_handlers.isEmpty) {
      throw StateError(
        'No queued response for ${request.method} ${request.url}',
      );
    }
    final handler = _handlers.removeFirst();
    return handler(request);
  }
}

class TestBackoffStrategy implements BackoffStrategy {
  TestBackoffStrategy(this.builder);

  final Duration? Function(int retryNumber) builder;

  @override
  Duration? delayForRetry(int retryNumber) => builder(retryNumber);
}
