import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class MockClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

void registerHttpFallbacks() {
  registerFallbackValue(Uri.parse('https://example.com'));
  registerFallbackValue(<String, String>{});
}

http.Response jsonResponse(Object? body, {int statusCode = 200}) {
  return http.Response(jsonEncode(body), statusCode,
      headers: {'content-type': 'application/json'});
}

/// Captures the JSON body of the single `post` call made to [client].
///
/// mocktail orders `.captured` as: positional captures first (in call order),
/// then named captures in the order they appear in the `verify` call — so
/// with `post(captureAny(), headers: captureAny(...), body: captureAny(...))`
/// the list is `[uri, headers, body]`.
Map<String, Object?> capturedJsonBody(MockClient client) {
  final captured = verify(
    () => client.post(captureAny(),
        headers: captureAny(named: 'headers'), body: captureAny(named: 'body')),
  ).captured;
  final body = captured[2] as String;
  return jsonDecode(body) as Map<String, Object?>;
}
