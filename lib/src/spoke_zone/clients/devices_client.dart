import 'dart:convert';

import 'package:http/http.dart' as http;

import '../access_token_provider.dart';
import '../http_helpers.dart';
import '../models/coordinates.dart';
import '../models/device_details.dart';
import '../retry.dart';

class DevicesClient {
  DevicesClient({
    required this.httpClient,
    required this.baseUri,
    required this.auth,
    required BackoffStrategy backoffStrategy,
    required DelayFn delay,
  })  : _backoffStrategy = backoffStrategy,
        _delay = delay;

  final http.Client httpClient;
  final Uri baseUri;
  final AccessTokenProvider auth;
  final BackoffStrategy _backoffStrategy;
  final DelayFn _delay;

  Future<DeviceDetails> get(int id) async {
    final response = await sendAuthorizedJsonWithRetry(
      httpClient: httpClient,
      auth: auth,
      requestBuilder: (token) {
        final req = http.Request('GET', baseUri.replace(path: '/api/v2/devices/$id'));
        req.headers['x-access-token'] = token;
        return req;
      },
      backoffStrategy: _backoffStrategy,
      delay: _delay,
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    final lastOnlineRaw = body['lastOnline'] as String?;
    final lastOnline = lastOnlineRaw == null ? null : DateTime.tryParse(lastOnlineRaw);

    final latRaw = body['lastLatitude'];
    final lonRaw = body['lastLongitude'];
    Coordinates? lastLocation;
    if (latRaw is num && lonRaw is num) {
      lastLocation = Coordinates(
        latitude: latRaw.toDouble(),
        longitude: lonRaw.toDouble(),
      );
    }

    final softwareVersionsRaw = body['softwareVersions'];
    final softwareVersions = <String, String>{};
    if (softwareVersionsRaw is Map<String, dynamic>) {
      softwareVersionsRaw.forEach((key, value) {
        if (value is String) {
          softwareVersions[key] = value;
        }
      });
    }

    return DeviceDetails(
      id: body['id'] as int,
      identifier: body['identifier'] as String,
      serialNumber: body['serialNumber'] as String,
      modelId: body['modelId'] as int,
      modelName: body['name'] as String,
      lastOnline: lastOnline,
      lastLocation: lastLocation,
      softwareVersions: softwareVersions,
    );
  }
}
