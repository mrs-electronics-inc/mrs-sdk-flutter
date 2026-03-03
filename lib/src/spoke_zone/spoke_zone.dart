import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'errors.dart';
import 'models.dart';

abstract interface class AccessTokenProvider {
  Future<String> getAccessToken();
}

abstract class _CachedAccessTokenProvider implements AccessTokenProvider {
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

class DeviceAuth extends _CachedAccessTokenProvider {
  DeviceAuth({
    required this.baseUri,
    required this.callbacks,
    required this.httpClient,
  });

  final Uri baseUri;
  final DeviceAuthCallbacks callbacks;
  final http.Client httpClient;

  @override
  Future<String> login() async {
    final seedToken = await callbacks.initialDeviceToken();
    final response = await _sendWithRetry(() async {
      final req = http.Request('POST', baseUri.replace(path: '/loginDevice'));
      req.headers['content-type'] = 'application/json';
      req.body = jsonEncode({
        'token': seedToken,
        'cpu_id': await callbacks.cpuId(),
        'uuid': await callbacks.uuid(),
      });
      return req;
    }, (request) => httpClient.send(request));

    if (response.statusCode == 201) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      cacheToken(body['token'] as String);
    } else {
      cacheToken(seedToken);
    }
    return getAccessToken();
  }
}

class UserAuth extends _CachedAccessTokenProvider {
  UserAuth({
    required this.baseUri,
    required this.callbacks,
    required this.httpClient,
  });

  final Uri baseUri;
  final UserAuthCallbacks callbacks;
  final http.Client httpClient;

  @override
  Future<String> login() async {
    final response = await _sendWithRetry(() async {
      final req = http.Request('POST', baseUri.replace(path: '/login'));
      req.headers['content-type'] = 'application/json';
      req.body = jsonEncode({
        'username': await callbacks.username(),
        'password': await callbacks.password(),
      });
      return req;
    }, (request) => httpClient.send(request));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    cacheToken(body['token'] as String);
    return getAccessToken();
  }
}

class SpokeZone {
  SpokeZone({required this.config, required this.httpClient}) {
    final auth = _buildAuthProvider(config: config, httpClient: httpClient);

    devices = DevicesClient(httpClient: httpClient, baseUri: config.baseUri, auth: auth);
    otaFiles = OtaFilesClient(httpClient: httpClient, baseUri: config.baseUri, auth: auth);
    dataFiles = DataFilesClient(httpClient: httpClient, baseUri: config.baseUri, auth: auth);
  }

  final SpokeZoneConfig config;
  final http.Client httpClient;
  late final DevicesClient devices;
  late final OtaFilesClient otaFiles;
  late final DataFilesClient dataFiles;

  static AccessTokenProvider _buildAuthProvider({
    required SpokeZoneConfig config,
    required http.Client httpClient,
  }) {
    return switch (config.authMode) {
      SpokeZoneAuthMode.device => DeviceAuth(
          baseUri: config.baseUri,
          callbacks: config.deviceAuth!,
          httpClient: httpClient,
        ),
      SpokeZoneAuthMode.user => UserAuth(
          baseUri: config.baseUri,
          callbacks: config.userAuth!,
          httpClient: httpClient,
        ),
    };
  }
}

class DevicesClient {
  DevicesClient({
    required this.httpClient,
    required this.baseUri,
    required this.auth,
  });

  final http.Client httpClient;
  final Uri baseUri;
  final AccessTokenProvider auth;

  Future<DeviceDetails> get(int id) async {
    final token = await auth.getAccessToken();
    final req = http.Request('GET', baseUri.replace(path: '/api/v2/devices/$id'));
    req.headers['x-access-token'] = token;
    final response = await http.Response.fromStream(await httpClient.send(req));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return DeviceDetails(
      id: body['id'] as int,
      identifier: body['identifier'] as String,
      serialNumber: body['serialNumber'] as String,
      modelId: body['modelId'] as int,
      modelName: body['name'] as String,
    );
  }
}

class OtaFilesClient {
  OtaFilesClient({
    required this.httpClient,
    required this.baseUri,
    required this.auth,
  });

  final http.Client httpClient;
  final Uri baseUri;
  final AccessTokenProvider auth;

  Future<List<OtaFile>> list() async {
    final token = await auth.getAccessToken();
    final uri = baseUri.replace(
      path: '/api/v2/ota-files',
      queryParameters: const {'limit': '50', 'offset': '0'},
    );
    final req = http.Request('GET', uri);
    req.headers['x-access-token'] = token;
    final response = await http.Response.fromStream(await httpClient.send(req));
    final body = jsonDecode(response.body) as List<dynamic>;
    return body.map((item) {
      final map = item as Map<String, dynamic>;
      return OtaFile(
        id: map['id'] as int,
        modelId: map['modelId'] as int,
        moduleId: map['moduleId'] as int,
        module: map['module'] as String,
        version: map['version'] as String,
        fileLocation: map['fileLocation'] as String,
        isActive: map['isActive'] as bool,
        createdDate: map['createdDate'] as String,
        releaseNotes: map['releaseNotes'] as String,
      );
    }).toList(growable: false);
  }
}

class DataFilesClient {
  DataFilesClient({
    required this.httpClient,
    required this.baseUri,
    required this.auth,
  });

  final http.Client httpClient;
  final Uri baseUri;
  final AccessTokenProvider auth;
}

Future<http.Response> _sendWithRetry(
  Future<http.Request> Function() buildRequest,
  Future<http.StreamedResponse> Function(http.Request request) send,
) async {
  var attempt = 0;
  while (true) {
    final request = await buildRequest();
    final response = await http.Response.fromStream(await send(request));
    if (!_isError(response.statusCode)) {
      return response;
    }
    if (_isRetryable(response.statusCode) && attempt < 2) {
      attempt += 1;
      continue;
    }
    throw SpokeZoneException(
      code: _mapStatus(response.statusCode),
      message: 'Auth request failed with status ${response.statusCode}',
    );
  }
}

bool _isError(int statusCode) => statusCode >= 400;
bool _isRetryable(int statusCode) => statusCode == 429 || statusCode >= 500;

SpokeZoneErrorCode _mapStatus(int statusCode) {
  return switch (statusCode) {
    401 => SpokeZoneErrorCode.unauthorized,
    403 => SpokeZoneErrorCode.forbidden,
    404 => SpokeZoneErrorCode.notFound,
    429 => SpokeZoneErrorCode.rateLimited,
    >= 500 => SpokeZoneErrorCode.serverError,
    _ => SpokeZoneErrorCode.unknown,
  };
}
