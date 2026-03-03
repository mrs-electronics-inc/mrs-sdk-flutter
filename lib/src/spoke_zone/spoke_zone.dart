import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'models.dart';

abstract interface class AccessTokenProvider {
  Future<String> getAccessToken();
}

class DeviceAuth implements AccessTokenProvider {
  DeviceAuth({
    required this.baseUri,
    required this.callbacks,
    required this.httpClient,
  });

  final Uri baseUri;
  final DeviceAuthCallbacks callbacks;
  final http.Client httpClient;
  String? _token;

  Future<String> login() async {
    final req = http.Request('POST', baseUri.replace(path: '/loginDevice'));
    req.headers['content-type'] = 'application/json';
    req.body = jsonEncode({
      'token': await callbacks.initialDeviceToken(),
      'cpu_id': await callbacks.cpuId(),
      'uuid': await callbacks.uuid(),
    });

    final response = await http.Response.fromStream(await httpClient.send(req));
    if (response.statusCode == 201) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      _token = body['token'] as String;
    } else {
      _token = await callbacks.initialDeviceToken();
    }
    return _token!;
  }

  @override
  Future<String> getAccessToken() async {
    if (_token != null) {
      return _token!;
    }
    return login();
  }
}

class UserAuth implements AccessTokenProvider {
  UserAuth({
    required this.baseUri,
    required this.callbacks,
    required this.httpClient,
  });

  final Uri baseUri;
  final UserAuthCallbacks callbacks;
  final http.Client httpClient;
  String? _token;

  Future<String> login() async {
    final req = http.Request('POST', baseUri.replace(path: '/login'));
    req.headers['content-type'] = 'application/json';
    req.body = jsonEncode({
      'username': await callbacks.username(),
      'password': await callbacks.password(),
    });

    final response = await http.Response.fromStream(await httpClient.send(req));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    _token = body['token'] as String;
    return _token!;
  }

  @override
  Future<String> getAccessToken() async {
    if (_token != null) {
      return _token!;
    }
    return login();
  }
}

class SpokeZone {
  SpokeZone({required this.config, required this.httpClient}) {
    final auth = switch (config.authMode) {
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

    devices = DevicesClient(httpClient: httpClient, baseUri: config.baseUri, auth: auth);
    otaFiles = OtaFilesClient(httpClient: httpClient, baseUri: config.baseUri, auth: auth);
    dataFiles = DataFilesClient(httpClient: httpClient, baseUri: config.baseUri, auth: auth);
  }

  final SpokeZoneConfig config;
  final http.Client httpClient;
  late final DevicesClient devices;
  late final OtaFilesClient otaFiles;
  late final DataFilesClient dataFiles;
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
