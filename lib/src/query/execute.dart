/// Executes a built query-builder state against `/api/db/query`.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../internal/parsing.dart';
import '../internal/query_state.dart';
import '../types.dart';

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

Future<QueryResult<Map<String, Object?>>> executeQuery(
    http.Client client, QueryState state) async {
  if (state.baseUrl.isEmpty) {
    throw StateError(
        '[postbase] url is required — ensure the Postbase URL is set');
  }

  final headers = <String, String>{
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${state.apiKey}',
    ...state.extraHeaders,
  };
  if (state.cookieAdapter != null) {
    final cookies =
        await _resolveFutureOr<List<Cookie>>(state.cookieAdapter!.getAll());
    final sessionCookie = _findSessionCookie(cookies);
    if (sessionCookie != null) {
      headers['X-Postbase-Session'] = sessionCookie.value;
    }
  }

  final built = buildRequestBody(state);

  try {
    final res = await client.post(
      Uri.parse('${state.baseUrl}/api/db/query'),
      headers: headers,
      body: jsonEncode(built.body),
    );
    final json = res.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(res.body) as Map<String, Object?>;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return QueryResult(
          data: null,
          count: null,
          error: json['error'] as String? ?? 'Query failed');
    }
    final rawData =
        ((json['data'] as List?) ?? const []).cast<Map<String, Object?>>();
    final data = built.parsedColumns.isNotEmpty
        ? applyAliases(rawData, built.parsedColumns)
        : rawData;
    return QueryResult(data: data, count: json['count'] as int?, error: null);
  } catch (err) {
    return QueryResult(data: null, count: null, error: err.toString());
  }
}
