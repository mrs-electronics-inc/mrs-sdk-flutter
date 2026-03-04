import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../access_token_provider.dart';
import '../http_helpers.dart';
import '../models/ota_file.dart';
import '../models/ota_files_list_options.dart';
import '../retry.dart';

/// Client for OTA file endpoints.
class OtaFilesClient {
  /// Creates an OTA files client.
  OtaFilesClient({
    required this.httpClient,
    required this.baseUri,
    required this.auth,
    required BackoffStrategy backoffStrategy,
    required DelayFn delay,
  }) : _backoffStrategy = backoffStrategy,
       _delay = delay;

  final http.Client httpClient;
  final Uri baseUri;
  final AccessTokenProvider auth;
  final BackoffStrategy _backoffStrategy;
  final DelayFn _delay;

  /// Lists OTA files with optional [options].
  Future<List<OtaFile>> list({
    OtaFilesListOptions options = const OtaFilesListOptions(),
  }) async {
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
    if (options.module != null) {
      query['module'] = options.module!;
    }
    if (options.isActive != null) {
      query['isActive'] = '${options.isActive!}';
    }

    final uri = baseUri.replace(
      path: '/api/v2/ota-files',
      queryParameters: query,
    );
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
    return body
        .map((item) {
          final map = item as Map<String, dynamic>;
          return OtaFile(
            id: map['id'] as int,
            modelId: map['modelId'] as int,
            moduleId: map['moduleId'] as int,
            module: map['module'] as String,
            version: map['version'] as String,
            fileLocation: map['fileLocation'] as String,
            isActive: map['isActive'] as bool,
            createdDate: _parseOptionalDate(map['createdDate']),
            releaseDate: _parseOptionalDate(map['releaseDate']),
            releaseNotes: map['releaseNotes'] as String,
          );
        })
        .toList(growable: false);
  }

  /// Downloads OTA file content as raw bytes for [id].
  Future<Uint8List> download(int id) async {
    final response = await sendAuthorizedJsonWithRetry(
      httpClient: httpClient,
      auth: auth,
      requestBuilder: (token) {
        final req = http.Request(
          'GET',
          baseUri.replace(path: '/api/v2/ota-files/$id/file'),
        );
        req.headers['x-access-token'] = token;
        return req;
      },
      backoffStrategy: _backoffStrategy,
      delay: _delay,
    );
    return Uint8List.fromList(response.bodyBytes);
  }

  DateTime? _parseOptionalDate(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}
