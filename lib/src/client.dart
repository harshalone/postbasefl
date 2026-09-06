/// The main Postbase client — mirrors `createClient()` in postbasejs.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth/auth_client.dart';
import 'email/email_client.dart';
import 'internal/query_state.dart';
import 'internal/session_storage.dart';
import 'query/query_builder.dart';
import 'storage/storage_client.dart';
import 'types.dart';

const String _defaultStorageKey = 'postbase_session';

Cookie? _findSessionCookie(List<Cookie> cookies) {
  for (final c in cookies) {
    if (c.name.startsWith('postbase-session') ||
        c.name == 'next-auth.session-token' ||
        c.name == '__Secure-next-auth.session-token') {
      return c;
    }
  }
  return null;
}

Future<T> _resolveFutureOr<T>(Object? value) async {
  if (value is Future<T>) return await value;
  return value as T;
}

/// Options accepted by [createClient].
class PostbaseClientOptions {
  const PostbaseClientOptions({
    this.projectId,
    this.persistSession = true,
    this.autoRefreshToken = true,
    this.storageKey,
    this.headers,
    this.cookies,
    this.httpClient,
  });

  /// The project ID, used to scope `/api/auth/v1/{projectId}/...` and
  /// `/api/email/v1/{projectId}/...` calls.
  final String? projectId;

  /// Persist the session to device storage (shared_preferences +
  /// flutter_secure_storage). Set to `false` for short-lived/service clients.
  final bool persistSession;

  /// Automatically schedule a refresh shortly before the access token expires.
  final bool autoRefreshToken;

  /// Storage key prefix used for persisted session data. Defaults to
  /// `postbase_session`.
  final String? storageKey;

  /// Extra headers sent with every request.
  final Map<String, String>? headers;

  /// A [CookieAdapter] for Dart backend (shelf/dart_frog) session forwarding.
  /// Not used in Flutter apps — those have no server-rendered request cycle.
  final CookieAdapter? cookies;

  /// An existing [http.Client] to reuse. One is created if omitted — call
  /// [PostbaseClient.dispose] to close it when you're done with the client.
  final http.Client? httpClient;
}

/// The main Postbase client. Create via [createClient].
class PostbaseClient {
  PostbaseClient._(
    this.url,
    this.key,
    this._client,
    this._ownsClient,
    this._projectId,
    this._extraHeaders, {
    CookieAdapter? cookieAdapter,
    required bool persistSession,
    required bool autoRefreshToken,
    String? storageKey,
  })  : _cookieAdapter = cookieAdapter,
        auth = AuthClient(
          client: _client,
          baseUrl: url,
          apiKey: key,
          projectId: _projectId,
          extraHeaders: _extraHeaders,
          cookieAdapter: cookieAdapter,
          sessionStorage: persistSession
              ? SessionStorage(storageKey: storageKey ?? _defaultStorageKey)
              : null,
          persistSession: persistSession,
          autoRefreshToken: autoRefreshToken,
        ),
        email = EmailClient(_client, url, key, _projectId, _extraHeaders),
        storage = StorageClient(_client, url, key, _extraHeaders);

  /// The raw base URL.
  final String url;

  /// The API key in use.
  final String key;

  /// The project ID this client is scoped to, if any.
  String get projectId => _projectId;

  final http.Client _client;
  final bool _ownsClient;
  final String _projectId;
  final Map<String, String> _extraHeaders;
  final CookieAdapter? _cookieAdapter;

  final AuthClient auth;
  final EmailClient email;
  final StorageClient storage;

  /// Start a query against [table]. Rows are returned as
  /// `Map<String, Object?>` unless you pass a [map] function to decode them
  /// into your own type.
  QueryBuilder<T> from<T>(String table,
      {T Function(Map<String, Object?>)? map}) {
    final state = QueryState(
      baseUrl: url,
      apiKey: key,
      table: table,
      extraHeaders: _extraHeaders,
      cookieAdapter: _cookieAdapter,
    );
    final mapper = map ?? ((Map<String, Object?> row) => row as T);
    return QueryBuilder<T>(_client, state, mapper);
  }

  Future<Map<String, String>> _headersWithSession() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $key',
      ..._extraHeaders,
    };
    if (_cookieAdapter != null) {
      final cookies =
          await _resolveFutureOr<List<Cookie>>(_cookieAdapter.getAll());
      final sessionCookie = _findSessionCookie(cookies);
      if (sessionCookie != null) {
        headers['X-Postbase-Session'] = sessionCookie.value;
      }
    }
    return headers;
  }

  /// Execute a raw parameterized SQL query. Params replace `$1`, `$2`, …
  /// positional placeholders — never string-interpolate values. RLS context
  /// is still enforced.
  Future<QueryResult<Map<String, Object?>>> sql(String query,
      [List<Object?>? params]) async {
    if (url.isEmpty) {
      throw StateError(
          '[postbase] url is required — ensure the Postbase URL is set');
    }
    try {
      final headers = await _headersWithSession();
      final res = await _client.post(
        Uri.parse('$url/api/db/sql'),
        headers: headers,
        body: jsonEncode({'query': query, 'params': params ?? const []}),
      );
      final json = jsonDecode(res.body) as Map<String, Object?>;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return QueryResult(
            data: null,
            count: null,
            error: json['error'] as String? ?? 'SQL query failed');
      }
      final data =
          ((json['data'] as List?) ?? const []).cast<Map<String, Object?>>();
      return QueryResult(data: data, count: json['count'] as int?, error: null);
    } catch (err) {
      return QueryResult(data: null, count: null, error: err.toString());
    }
  }

  /// Call a PostgreSQL function in the project's schema.
  Future<QueryResult<Map<String, Object?>>> rpc(
    String fn, {
    Map<String, Object?>? args,
    RpcOptions options = const RpcOptions(),
  }) async {
    if (url.isEmpty) {
      throw StateError(
          '[postbase] url is required — ensure the Postbase URL is set');
    }
    try {
      final headers = await _headersWithSession();
      final res = await _client.post(
        Uri.parse('$url/api/rpc/$fn'),
        headers: headers,
        body: jsonEncode({'args': args ?? const {}, 'count': options.count}),
      );
      final json = jsonDecode(res.body) as Map<String, Object?>;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return QueryResult(
            data: null,
            count: null,
            error: json['error'] as String? ?? 'RPC failed');
      }
      final rawData = json['data'];
      final data = rawData is List
          ? rawData.cast<Map<String, Object?>>()
          : rawData == null
              ? const <Map<String, Object?>>[]
              : <Map<String, Object?>>[rawData as Map<String, Object?>];
      return QueryResult(data: data, count: json['count'] as int?, error: null);
    } catch (err) {
      return QueryResult(data: null, count: null, error: err.toString());
    }
  }

  /// Closes the underlying HTTP client (only if this client created it) and
  /// releases auth resources (timers, stream controller).
  void dispose() {
    auth.dispose();
    if (_ownsClient) _client.close();
  }
}

/// Create a Postbase client.
///
/// ```dart
/// final postbase = createClient(
///   'https://your-postbase-instance.com',
///   'pb_anon_your_api_key',
///   options: const PostbaseClientOptions(projectId: 'your-project-id'),
/// );
/// ```
PostbaseClient createClient(String url, String key,
    {PostbaseClientOptions options = const PostbaseClientOptions()}) {
  final baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  final client = options.httpClient ?? http.Client();
  return PostbaseClient._(
    baseUrl,
    key,
    client,
    options.httpClient == null,
    options.projectId ?? '',
    options.headers ?? const {},
    cookieAdapter: options.cookies,
    persistSession: options.persistSession,
    autoRefreshToken: options.autoRefreshToken,
    storageKey: options.storageKey,
  );
}
