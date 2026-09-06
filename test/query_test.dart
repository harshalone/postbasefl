import 'dart:convert';

import 'package:http/http.dart' as http;
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

  test('select builds expected body and headers', () async {
    when(() => client.post(any(),
        headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse({
        'data': [
          {'id': '1', 'title': 'Hello'}
        ],
        'count': 1,
      }),
    );

    final result = await postbase
        .from('posts')
        .select('id, title')
        .eq('status', 'published')
        .order('created_at', ascending: false)
        .limit(10);

    expect(result.error, isNull);
    expect(result.data, [
      {'id': '1', 'title': 'Hello'}
    ]);
    expect(result.count, 1);

    final captured = verify(
      () => client.post(captureAny(),
          headers: captureAny(named: 'headers'),
          body: captureAny(named: 'body')),
    ).captured;
    final uri = captured[0] as Uri;
    final headers = captured[1] as Map<String, String>;
    final body = jsonDecode(captured[2] as String) as Map<String, Object?>;

    expect(uri.toString(), 'https://example.com/api/db/query');
    expect(headers['Authorization'], 'Bearer pb_anon_test');
    expect(body['operation'], 'select');
    expect(body['table'], 'posts');
    expect(body['columns'], ['id', 'title']);
    expect(body['filters'], [
      {'column': 'status', 'operator': 'eq', 'value': 'published'}
    ]);
    expect(body['order'], [
      {'column': 'created_at', 'ascending': false}
    ]);
    expect(body['limit'], 10);
  });

  test('select with alias renames result keys', () async {
    when(() => client.post(any(),
        headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse({
        'data': [
          {'id': '1', 'name': 'Foo'}
        ],
        'count': null,
      }),
    );

    final result =
        await postbase.from('apis').select('apis.id as api_id, apis.name');
    expect(result.data, [
      {'api_id': '1', 'name': 'Foo'}
    ]);
  });

  test('single errors when no rows', () async {
    when(() => client.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => jsonResponse({'data': [], 'count': 0}));

    final result =
        await postbase.from('posts').select().eq('id', 'missing').single();
    expect(result.data, isNull);
    expect(result.error, 'No rows returned');
  });

  test('maybeSingle returns null without error', () async {
    when(() => client.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => jsonResponse({'data': [], 'count': 0}));

    final result =
        await postbase.from('posts').select().eq('id', 'missing').maybeSingle();
    expect(result.data, isNull);
    expect(result.error, isNull);
  });

  test('insert returns a single row', () async {
    when(() => client.post(any(),
        headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse({
        'data': [
          {'id': '1', 'title': 'New'}
        ],
        'count': null,
      }),
    );

    final result =
        await postbase.from('posts').insert({'title': 'New'}).select().single();
    expect(result.data, {'id': '1', 'title': 'New'});
  });

  test('query error response is surfaced', () async {
    when(() =>
        client.post(any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'))).thenAnswer(
        (_) async => jsonResponse({'error': 'bad request'}, statusCode: 400));

    final result = await postbase.from('posts').select();
    expect(result.data, isNull);
    expect(result.error, 'bad request');
  });

  test('or filter sent as orFilters', () async {
    when(() => client.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => jsonResponse({'data': [], 'count': 0}));

    await postbase.from('users').select().or('email.ilike.%a%,name.ilike.%a%');

    final body = capturedJsonBody(client);
    expect(body['orFilters'], [
      [
        {'column': 'email', 'operator': 'ilike', 'value': '%a%'},
        {'column': 'name', 'operator': 'ilike', 'value': '%a%'},
      ]
    ]);
  });

  test('join is sent with type', () async {
    when(() => client.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => jsonResponse({'data': [], 'count': 0}));

    await postbase
        .from('orders')
        .join('users', on: 'orders.user_id = users.id', type: JoinType.left)
        .select('orders.id, users.email');

    final body = capturedJsonBody(client);
    expect(body['joins'], [
      {'table': 'users', 'on': 'orders.user_id = users.id', 'type': 'left'}
    ]);
  });

  test('upsert sends onConflict', () async {
    when(() => client.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => jsonResponse({'data': [], 'count': 0}));

    await postbase
        .from('profiles')
        .upsert({'id': 'user-id', 'username': 'alice'}, onConflict: 'id');

    final body = capturedJsonBody(client);
    expect(body['operation'], 'upsert');
    expect(body['onConflict'], 'id');
    expect(body['data'], {'id': 'user-id', 'username': 'alice'});
  });

  test('range sets limit and offset', () async {
    when(() => client.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => jsonResponse({'data': [], 'count': 0}));

    await postbase.from('posts').select().range(0, 19);

    final body = capturedJsonBody(client);
    expect(body['range'], {'from': 0, 'to': 19});
    expect(body['limit'], 20);
    expect(body['offset'], 0);
  });

  test('delete sends delete operation with filters', () async {
    when(() => client.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => jsonResponse({'data': [], 'count': 0}));

    await postbase.from('posts').delete().eq('id', 'post-id');

    final body = capturedJsonBody(client);
    expect(body['operation'], 'delete');
    expect(body['filters'], [
      {'column': 'id', 'operator': 'eq', 'value': 'post-id'}
    ]);
  });

  test('not filter is sent', () async {
    when(() => client.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => jsonResponse({'data': [], 'count': 0}));

    await postbase.from('posts').select().not('status', 'eq', 'archived');

    final body = capturedJsonBody(client);
    expect(body['notFilters'], [
      {'column': 'status', 'operator': 'eq', 'value': 'archived'}
    ]);
  });

  test('in and is filters use unmangled wire operator names', () async {
    when(() => client.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => jsonResponse({'data': [], 'count': 0}));

    await postbase
        .from('posts')
        .select()
        .in_('status', ['draft', 'published']).is_('deleted_at', null);

    final body = capturedJsonBody(client);
    expect(body['filters'], [
      {
        'column': 'status',
        'operator': 'in',
        'value': ['draft', 'published']
      },
      {'column': 'deleted_at', 'operator': 'is', 'value': null},
    ]);
  });

  test('count option is forwarded', () async {
    when(() => client.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => jsonResponse({'data': [], 'count': 5}));

    final result = await postbase
        .from('posts')
        .select('*', const SelectOptions(count: 'exact'));
    expect(result.count, 5);

    final body = capturedJsonBody(client);
    expect(body['count'], 'exact');
  });

  test('network exception is surfaced as error', () async {
    when(() => client.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')))
        .thenThrow(http.ClientException('network down'));

    final result = await postbase.from('posts').select();
    expect(result.data, isNull);
    expect(result.error, contains('network down'));
  });
}
