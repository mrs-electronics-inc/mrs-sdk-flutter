import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../access_token_provider.dart';
import '../http_helpers.dart';
import '../models.dart';
import '../retry.dart';

class OtaFilesClient {
  OtaFilesClient({
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

  Future<List<OtaFile>> list({OtaFilesListOptions options = const OtaFilesListOptions()}) async {
    final query = <String, String>{
      'limit': '${options.limit}',
      'offset': '${options.offset}',
    };
    if (options.searchTerm != null) {
      query['searchTerm'] = options.searchTerm!;
    }
    if (options.searchFields != null) {
      query['searchFields'] = options.searchFields!;
    }
    if (options.sort != null) {
      query['sort'] = options.sort!;
    }
    if (options.sortOrder != null) {
      query['sortOrder'] = options.sortOrder!;
    }

    final uri = baseUri.replace(path: '/api/v2/ota-files', queryParameters: query);
    final response = await sendAuthorizedJsonWithRetry(
      httpClient: httpClient,
      auth: auth,
      requestBuilder: (token) {
        final req = http.Request('GET', uri);
        req.headers['x-access-token'] = token;
        return req;
      },
      backoffStrategy: _backoffStrategy,
      delay: _delay,
    );
    final body = decodeJsonList(response.body);
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

  Future<Uint8List> download(int id) async {
    final response = await sendAuthorizedJsonWithRetry(
      httpClient: httpClient,
      auth: auth,
      requestBuilder: (token) {
        final req = http.Request('GET', baseUri.replace(path: '/api/v2/ota-files/$id/file'));
        req.headers['x-access-token'] = token;
        return req;
      },
      backoffStrategy: _backoffStrategy,
      delay: _delay,
    );
    return Uint8List.fromList(response.bodyBytes);
  }
}
