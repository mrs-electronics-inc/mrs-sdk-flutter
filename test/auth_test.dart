import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mrs_sdk_flutter/mrs_sdk_flutter.dart';

import 'helpers.dart';

void main() {
  group('Auth providers', () {
    test('DeviceAuth.login sends expected request and handles 200/201', () async {
      final client = QueuedClient();
      client.enqueueJson(200, {'status': 'ok'});

      final auth200 = DeviceAuth(
        baseUri: Uri.parse('https://api.spoke.zone'),
        callbacks: deviceCallbacks(),
        httpClient: client,
      );

      final token200 = await auth200.login();
      expect(token200, 'initial-device-token');
      final request200 = client.requests.single as http.Request;
      expect(request200.method, 'POST');
      expect(request200.url.path, '/loginDevice');
      final body200 = jsonDecode(request200.body) as Map<String, dynamic>;
      expect(body200['token'], 'initial-device-token');
      expect(body200['cpu_id'], 'cpu-1');
      expect(body200['uuid'], 'uuid-1');

      final renewedClient = QueuedClient();
      renewedClient.enqueueJson(201, {'token': 'renewed-token'});
      final auth201 = DeviceAuth(
        baseUri: Uri.parse('https://api.spoke.zone'),
        callbacks: deviceCallbacks(),
        httpClient: renewedClient,
      );

      expect(await auth201.login(), 'renewed-token');
    });

    test('DeviceAuth.login maps terminal errors', () async {
      final client = QueuedClient();
      client.enqueueJson(403, {'message': 'forbidden'});
      final auth = DeviceAuth(
        baseUri: Uri.parse('https://api.spoke.zone'),
        callbacks: deviceCallbacks(),
        httpClient: client,
      );

      await expectLater(
        auth.login(),
        throwsA(
          isA<SpokeZoneException>().having(
            (e) => e.code,
            'code',
            SpokeZoneErrorCode.forbidden,
          ),
        ),
      );
    });

    test('UserAuth.login uses username/password callbacks and token lifecycle entry points', () async {
      final client = QueuedClient();
      client.enqueueJson(200, {
        'token': 'user-token',
        'expires': 1,
        'user': {'username': 'u'},
      });

      final auth = UserAuth(
        baseUri: Uri.parse('https://api.spoke.zone'),
        callbacks: userCallbacks(),
        httpClient: client,
        delay: (_) async {},
      );

      final token = await auth.login();
      expect(token, 'user-token');

      final request = client.requests.single as http.Request;
      expect(request.url.path, '/login');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body, {'username': 'user-a', 'password': 'pw-a'});

      expect(await auth.getAccessToken(), 'user-token');
      expect(client.requests, hasLength(1));
    });

    test('UserAuth.login applies retry parity and failure mapping', () async {
      final client = QueuedClient();
      client.enqueueJson(500, {'error': 'server'});
      client.enqueueJson(429, {'error': 'rate'});
      client.enqueueJson(200, {
        'token': 'ok-token',
        'expires': 1,
        'user': {'username': 'u'},
      });

      final auth = UserAuth(
        baseUri: Uri.parse('https://api.spoke.zone'),
        callbacks: userCallbacks(),
        httpClient: client,
        delay: (_) async {},
      );

      expect(await auth.login(), 'ok-token');
      expect(client.requests, hasLength(3));

      final terminalClient = QueuedClient();
      terminalClient.enqueueJson(403, {'error': 'forbidden'});
      final terminal = UserAuth(
        baseUri: Uri.parse('https://api.spoke.zone'),
        callbacks: userCallbacks(),
        httpClient: terminalClient,
      );

      await expectLater(
        terminal.login(),
        throwsA(
          isA<SpokeZoneException>().having(
            (e) => e.code,
            'code',
            SpokeZoneErrorCode.forbidden,
          ),
        ),
      );
    });
  });
}
