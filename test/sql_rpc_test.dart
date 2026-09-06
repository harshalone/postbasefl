import 'dart:convert';

import 'package:mocktail/mocktail.dart';
import 'package:postbasefl/postbasefl.dart';
import 'package:test/test.dart';

import 'support/mock_client.dart';

void main() {
  setUpAll(registerHttpFallbacks);

  late MockClient client;
  late PostbaseClient postbase;

  setUp(() {
    client = MockClient();
    postbase = createClient(
      'https://example.com',
      'pb_anon_test',
      options: PostbaseClientOptions(
          projectId: 'proj1', httpClient: client, persistSession: false),
    );
  });

  test('sql sends positional params, never interpolated', () async {
    when(() => client.post(
          Uri.parse('https://example.com/api/db/sql'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => jsonResponse({
          'data': [
            {'id': '1', 'email': 'a@example.com'}
          ],
          'count': 1,
        }));

    final result = await postbase.sql(
      'SELECT o.id, u.email FROM orders o JOIN users u ON o.user_id = u.id WHERE o.status = \$1',
      ['active'],
    );

    expect(result.error, isNull);
    expect(result.data, [
      {'id': '1', 'email': 'a@example.com'}
    ]);

    final captured = verify(
      () => client.post(any(),
          headers: any(named: 'headers'), body: captureAny(named: 'body')),
    ).captured;
    final body = jsonDecode(captured.first as String) as Map<String, Object?>;
    expect(body['params'], ['active']);
    expect(body['query'], contains(r'$1'));
  });

  test('rpc sends args and count option', () async {
    when(() => client.post(
          Uri.parse('https://example.com/api/rpc/get_nearby_posts'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => jsonResponse({
          'data': [
            {'id': '1'}
          ],
          'count': 1,
        }));

    final result = await postbase
        .rpc('get_nearby_posts', args: {'lat': 37.77, 'lng': -122.42});
    expect(result.error, isNull);
    expect(result.data, [
      {'id': '1'}
    ]);

    final captured = verify(
      () => client.post(any(),
          headers: any(named: 'headers'), body: captureAny(named: 'body')),
    ).captured;
    final body = jsonDecode(captured.first as String) as Map<String, Object?>;
    expect(body['args'], {'lat': 37.77, 'lng': -122.42});
  });

  test('rpc surfaces errors', () async {
    when(() => client.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async =>
            jsonResponse({'error': 'function not found'}, statusCode: 400));

    final result = await postbase.rpc('missing_fn');
    expect(result.data, isNull);
    expect(result.error, 'function not found');
  });
}
