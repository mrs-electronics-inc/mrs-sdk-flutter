import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../access_token_provider.dart';
import '../errors.dart';
import '../http_helpers.dart';
import '../retry.dart';

/// Client for data file endpoints.
class DataFilesClient {
  /// Creates a data files client.
  DataFilesClient({
    required this.httpClient,
    required this.baseUri,
    required this.auth,
    required BackoffStrategy backoffStrategy,
    required DelayFn delay,
  }) : _backoffStrategy = backoffStrategy,
       _delay = delay;

  /// HTTP client used for data-file API requests.
  final http.Client httpClient;

  /// Base Spoke.Zone API URI used to build data-file endpoints.
  final Uri baseUri;

  /// Access token provider used to authorize data-file requests.
  final AccessTokenProvider auth;
  final BackoffStrategy _backoffStrategy;
  final DelayFn _delay;

  static const Set<String> _allowedTypes = {
    'log',
    'event',
    'gps',
    'debug',
    'journal',
    'dmesg',
    'txt',
  };

  /// Creates a server-side data-file record and returns its ID.
  ///
  /// Supported [type] values: `log`, `event`, `gps`, `debug`, `journal`,
  /// `dmesg`, `txt`. Optionally associate the file with a module via
  /// [module], where the value should be the module key that identifies the
  /// target module.
  Future<int> create(String type, {String? module}) async {
    if (!_allowedTypes.contains(type)) {
      throw SpokeZoneException(
        code: SpokeZoneErrorCode.validationError,
        message: 'Unsupported data file type: $type',
      );
    }

    final response = await sendAuthorizedJsonWithRetry(
      httpClient: httpClient,
      auth: auth,
      requestBuilder: (token) {
        final req = http.Request(
          'POST',
          baseUri.replace(path: '/api/v2/data-files'),
        );
        req.headers['x-access-token'] = token;
        req.headers['content-type'] = 'application/json';
        final body = <String, Object?>{'type': type};
        if (module != null) {
          body['module'] = module;
        }
        req.body = jsonEncode(body);
        return req;
      },
      backoffStrategy: _backoffStrategy,
      delay: _delay,
    );
    final body = decodeJsonObject(response.body);
    return body['id'] as int;
  }

  /// Uploads raw [content] bytes to a previously created data file [id].
  Future<void> upload(int id, Uint8List content) async {
    final token = await auth.getAccessToken();
    final endpoint = '/api/v2/data-files/$id/file';
    try {
      final req = http.MultipartRequest(
        'POST',
        baseUri.replace(path: endpoint),
      );
      req.headers['x-access-token'] = token;
      req.files.add(
        http.MultipartFile.fromBytes('files', content, filename: 'upload.bin'),
      );
      final streamed = await httpClient.send(req);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode >= 400) {
        throw SpokeZoneException(
          code: mapStatus(response.statusCode),
          message: 'Upload failed with status ${response.statusCode}',
          endpoint: endpoint,
          httpStatus: response.statusCode,
          responseSnippet: snippet(response.body),
        );
      }
    } on SpokeZoneException {
      rethrow;
    } on http.ClientException catch (_) {
      throw SpokeZoneException(
        code: SpokeZoneErrorCode.networkError,
        message: 'Upload request failed due to network error',
        endpoint: endpoint,
      );
    }
  }
}
