/// Storage client — `/api/storage/v1/...`.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../types.dart';

String _encodePath(String path) =>
    path.split('/').map(Uri.encodeComponent).join('/');

class UploadResult {
  const UploadResult({required this.path, required this.fullPath});

  final String path;
  final String fullPath;
}

class SortBy {
  const SortBy({required this.column, this.order});

  final String column;

  /// `asc` or `desc`.
  final String? order;

  Map<String, Object?> toJson() =>
      {'column': column, if (order != null) 'order': order};
}

/// Operations scoped to a single bucket, returned by `storage.from(bucket)`.
class StorageBucketClient {
  StorageBucketClient(this._client, this._baseUrl, this._headers, this._bucket);

  final http.Client _client;
  final String _baseUrl;
  final Map<String, String> _headers;
  final String _bucket;

  /// Upload a file. [file] accepts [Uint8List] (works everywhere, including
  /// web) or a `dart:io File` (native platforms only — passed as `Object`
  /// here so this file has no `dart:io` dependency and stays web-compatible).
  Future<SingleResult<UploadResult>> upload(
    String path,
    Object file, {
    String? contentType,
    bool upsert = false,
    String? cacheControl,
  }) async {
    try {
      final bytes = await _readBytes(file);
      final filename = path.split('/').last;
      final uri = Uri.parse(
          '$_baseUrl/api/storage/v1/object/$_bucket/${_encodePath(path)}');
      final request = http.MultipartRequest(upsert ? 'PUT' : 'POST', uri)
        ..headers.addAll(_headers)
        ..fields['path'] = path
        ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: filename));
      if (upsert) request.fields['upsert'] = 'true';
      if (cacheControl != null) request.fields['cacheControl'] = cacheControl;

      final streamed = await _client.send(request);
      final res = await http.Response.fromStream(streamed);
      Map<String, Object?> json = const {};
      if (res.body.isNotEmpty) {
        try {
          json = jsonDecode(res.body) as Map<String, Object?>;
        } catch (_) {
          json = const {};
        }
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        final error = json['error'] as String? ??
            json['message'] as String? ??
            (res.body.isNotEmpty ? res.body : 'Upload failed');
        return SingleResult(data: null, error: error);
      }
      return SingleResult(
          data: UploadResult(path: path, fullPath: '$_bucket/$path'),
          error: null);
    } catch (err) {
      return SingleResult(data: null, error: err.toString());
    }
  }

  /// Download a file's bytes.
  Future<SingleResult<Uint8List>> download(String path) async {
    try {
      final res = await _client.get(
        Uri.parse(
            '$_baseUrl/api/storage/v1/object/$_bucket/${_encodePath(path)}'),
        headers: _headers,
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return const SingleResult(data: null, error: 'Download failed');
      }
      return SingleResult(data: res.bodyBytes, error: null);
    } catch (err) {
      return SingleResult(data: null, error: err.toString());
    }
  }

  /// Delete one or more objects by path.
  Future<QueryResult<Map<String, Object?>>> remove(List<String> paths) async {
    try {
      final res = await _client.delete(
        Uri.parse('$_baseUrl/api/storage/v1/object/$_bucket'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'prefixes': paths}),
      );
      final json = jsonDecode(res.body) as Map<String, Object?>;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return QueryResult(
            data: null,
            count: null,
            error: json['error'] as String? ?? 'Delete failed');
      }
      final data =
          ((json['data'] as List?) ?? const []).cast<Map<String, Object?>>();
      return QueryResult(
          data: data, count: data.isEmpty ? null : data.length, error: null);
    } catch (err) {
      return QueryResult(data: null, count: null, error: err.toString());
    }
  }

  /// List objects under [prefix].
  Future<QueryResult<StorageObject>> list(
    String prefix, {
    int limit = 100,
    int offset = 0,
    SortBy? sortBy,
  }) async {
    try {
      final res = await _client.post(
        Uri.parse('$_baseUrl/api/storage/v1/object/list/$_bucket'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'prefix': prefix,
          'limit': limit,
          'offset': offset,
          if (sortBy != null) 'sortBy': sortBy.toJson(),
        }),
      );
      final json = jsonDecode(res.body) as Map<String, Object?>;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return QueryResult(
            data: null,
            count: null,
            error: json['error'] as String? ?? 'List failed');
      }
      final data = ((json['data'] as List?) ?? const [])
          .map(
              (o) => StorageObject.fromJson((o as Map).cast<String, Object?>()))
          .toList();
      return QueryResult(
          data: data, count: data.isEmpty ? null : data.length, error: null);
    } catch (err) {
      return QueryResult(data: null, count: null, error: err.toString());
    }
  }

  /// Build the public URL for an object in a public bucket.
  String getPublicUrl(String path) {
    return '$_baseUrl/api/storage/v1/object/public/$_bucket/${_encodePath(path)}';
  }

  /// Create a temporary signed URL for a private object.
  Future<SingleResult<String>> createSignedUrl(
      String path, int expiresIn) async {
    try {
      final res = await _client.post(
        Uri.parse(
            '$_baseUrl/api/storage/v1/object/sign/$_bucket/${_encodePath(path)}'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'expiresIn': expiresIn}),
      );
      final json = jsonDecode(res.body) as Map<String, Object?>;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return SingleResult(
            data: null, error: json['error'] as String? ?? 'Sign failed');
      }
      return SingleResult(data: '$_baseUrl${json['signedUrl']}', error: null);
    } catch (err) {
      return SingleResult(data: null, error: err.toString());
    }
  }

  /// Move (rename) an object.
  Future<String?> move(String fromPath, String toPath) async {
    try {
      final res = await _client.post(
        Uri.parse('$_baseUrl/api/storage/v1/object/move'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'bucketId': _bucket,
          'sourceKey': fromPath,
          'destinationKey': toPath
        }),
      );
      final json = jsonDecode(res.body) as Map<String, Object?>;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return json['error'] as String? ?? 'Move failed';
      }
      return null;
    } catch (err) {
      return err.toString();
    }
  }

  /// Copy an object to a new path.
  Future<SingleResult<String>> copy(String fromPath, String toPath) async {
    try {
      final res = await _client.post(
        Uri.parse('$_baseUrl/api/storage/v1/object/copy'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'bucketId': _bucket,
          'sourceKey': fromPath,
          'destinationKey': toPath
        }),
      );
      final json = jsonDecode(res.body) as Map<String, Object?>;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return SingleResult(
            data: null, error: json['error'] as String? ?? 'Copy failed');
      }
      return SingleResult(data: toPath, error: null);
    } catch (err) {
      return SingleResult(data: null, error: err.toString());
    }
  }

  Future<Uint8List> _readBytes(Object file) async {
    if (file is Uint8List) return file;
    if (file is List<int>) return Uint8List.fromList(file);
    // Duck-type dart:io's File (readAsBytes() -> Future<Uint8List>) without
    // importing dart:io here, so this file stays web-compatible.
    try {
      final dynamic dyn = file;
      final Object? result = dyn.readAsBytes();
      if (result is Future<Uint8List>) return await result;
      if (result is Future<List<int>>) return Uint8List.fromList(await result);
    } catch (_) {
      // fall through to the ArgumentError below
    }
    throw ArgumentError.value(
        file, 'file', 'must be Uint8List, List<int>, or a dart:io File');
  }
}

/// Bucket management + `storage.from(bucket)` object operations.
class StorageClient {
  StorageClient(this._client, this._baseUrl, String apiKey,
      Map<String, String>? extraHeaders)
      : _headers = {'Authorization': 'Bearer $apiKey', ...?extraHeaders};

  final http.Client _client;
  final String _baseUrl;
  final Map<String, String> _headers;

  /// Get an object client scoped to [bucket].
  StorageBucketClient from(String bucket) =>
      StorageBucketClient(_client, _baseUrl, _headers, bucket);

  /// Create a new storage bucket.
  Future<SingleResult<Bucket>> createBucket(
    String name, {
    bool public = false,
    int? fileSizeLimit,
    List<String>? allowedMimeTypes,
  }) async {
    try {
      final res = await _client.post(
        Uri.parse('$_baseUrl/api/storage/v1/bucket'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'id': name,
          'public': public,
          'file_size_limit': fileSizeLimit,
          'allowed_mime_types': allowedMimeTypes,
        }),
      );
      final json = jsonDecode(res.body) as Map<String, Object?>;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return SingleResult(
            data: null,
            error: json['error'] as String? ?? 'Create bucket failed');
      }
      return SingleResult(
          data: Bucket.fromJson((json['data'] as Map).cast<String, Object?>()),
          error: null);
    } catch (err) {
      return SingleResult(data: null, error: err.toString());
    }
  }

  /// Get a bucket's details.
  Future<SingleResult<Bucket>> getBucket(String id) async {
    try {
      final res = await _client.get(
          Uri.parse('$_baseUrl/api/storage/v1/bucket/$id'),
          headers: _headers);
      final json = jsonDecode(res.body) as Map<String, Object?>;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return SingleResult(
            data: null, error: json['error'] as String? ?? 'Get bucket failed');
      }
      return SingleResult(
          data: Bucket.fromJson((json['data'] as Map).cast<String, Object?>()),
          error: null);
    } catch (err) {
      return SingleResult(data: null, error: err.toString());
    }
  }

  /// List all buckets.
  Future<QueryResult<Bucket>> listBuckets() async {
    try {
      final res = await _client
          .get(Uri.parse('$_baseUrl/api/storage/v1/bucket'), headers: _headers);
      final json = jsonDecode(res.body) as Map<String, Object?>;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return QueryResult(
            data: null,
            count: null,
            error: json['error'] as String? ?? 'List buckets failed');
      }
      final data = ((json['data'] as List?) ?? const [])
          .map((b) => Bucket.fromJson((b as Map).cast<String, Object?>()))
          .toList();
      return QueryResult(data: data, count: data.length, error: null);
    } catch (err) {
      return QueryResult(data: null, count: null, error: err.toString());
    }
  }

  /// Update a bucket's settings.
  Future<SingleResult<Bucket>> updateBucket(
    String id, {
    bool? public,
    int? fileSizeLimit,
    List<String>? allowedMimeTypes,
  }) async {
    try {
      final res = await _client.put(
        Uri.parse('$_baseUrl/api/storage/v1/bucket/$id'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'public': public,
          'file_size_limit': fileSizeLimit,
          'allowed_mime_types': allowedMimeTypes,
        }),
      );
      final json = jsonDecode(res.body) as Map<String, Object?>;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return SingleResult(
            data: null,
            error: json['error'] as String? ?? 'Update bucket failed');
      }
      return SingleResult(
          data: Bucket.fromJson((json['data'] as Map).cast<String, Object?>()),
          error: null);
    } catch (err) {
      return SingleResult(data: null, error: err.toString());
    }
  }

  /// Delete a bucket. It must be empty first (409 otherwise).
  Future<String?> deleteBucket(String id) async {
    try {
      final res = await _client.delete(
          Uri.parse('$_baseUrl/api/storage/v1/bucket/$id'),
          headers: _headers);
      final json = res.body.isEmpty
          ? <String, Object?>{}
          : jsonDecode(res.body) as Map<String, Object?>;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return json['error'] as String? ?? 'Delete bucket failed';
      }
      return null;
    } catch (err) {
      return err.toString();
    }
  }

  /// Delete all objects in a bucket.
  Future<String?> emptyBucket(String id) async {
    try {
      final res = await _client.post(
          Uri.parse('$_baseUrl/api/storage/v1/bucket/$id/empty'),
          headers: _headers);
      final json = res.body.isEmpty
          ? <String, Object?>{}
          : jsonDecode(res.body) as Map<String, Object?>;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return json['error'] as String? ?? 'Empty bucket failed';
      }
      return null;
    } catch (err) {
      return err.toString();
    }
  }
}
