import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:postbasefl/postbasefl.dart';
import 'package:test/test.dart';

import 'support/mock_client.dart';

void main() {
  setUpAll(registerHttpFallbacks);
  setUpAll(() {
    registerFallbackValue(
        http.MultipartRequest('POST', Uri.parse('https://example.com')));
  });

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

  test('upload sends multipart request and returns path', () async {
    when(() => client.send(any())).thenAnswer((_) async {
      final res = http.Response(
        jsonEncode({'ok': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
      return http.StreamedResponse(
          Stream.value(utf8.encode(res.body)), res.statusCode,
          headers: res.headers);
    });

    final result = await postbase.storage.from('avatars').upload(
          'user-123.png',
          Uint8List.fromList([1, 2, 3]),
          contentType: 'image/png',
        );

    expect(result.error, isNull);
    expect(result.data?.path, 'user-123.png');
    expect(result.data?.fullPath, 'avatars/user-123.png');

    final captured = verify(() => client.send(captureAny())).captured;
    final request = captured.first as http.MultipartRequest;
    expect(request.method, 'POST');
    expect(request.url.toString(),
        'https://example.com/api/storage/v1/object/avatars/user-123.png');
  });

  test('upload surfaces error on non-2xx response', () async {
    when(() => client.send(any())).thenAnswer((_) async {
      final body = jsonEncode({'error': 'too large'});
      return http.StreamedResponse(Stream.value(utf8.encode(body)), 413);
    });

    final result = await postbase.storage
        .from('avatars')
        .upload('x.png', Uint8List.fromList([1]));
    expect(result.data, isNull);
    expect(result.error, 'too large');
  });

  test('getPublicUrl builds the expected url', () {
    final url = postbase.storage.from('avatars').getPublicUrl('user-123.png');
    expect(url,
        'https://example.com/api/storage/v1/object/public/avatars/user-123.png');
  });

  test('list returns storage objects', () async {
    when(() => client.post(
          Uri.parse('https://example.com/api/storage/v1/object/list/avatars'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => jsonResponse({
          'data': [
            {
              'name': 'a.png',
              'size': 100,
              'contentType': 'image/png',
              'updatedAt': '2024-01-01',
              'createdAt': '2024-01-01',
            }
          ],
        }));

    final result = await postbase.storage.from('avatars').list('');
    expect(result.error, isNull);
    expect(result.data?.first.name, 'a.png');
    expect(result.count, 1);
  });

  test('remove deletes objects by path', () async {
    when(() => client.delete(
          Uri.parse('https://example.com/api/storage/v1/object/avatars'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => jsonResponse({
          'data': [
            {'name': 'user-123.png'}
          ]
        }));

    final result =
        await postbase.storage.from('avatars').remove(['user-123.png']);
    expect(result.error, isNull);
    expect(result.data, [
      {'name': 'user-123.png'}
    ]);
  });

  test('createBucket sends snake_case options', () async {
    when(() => client.post(
          Uri.parse('https://example.com/api/storage/v1/bucket'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => jsonResponse({
          'data': {
            'id': 'avatars',
            'name': 'avatars',
            'public': true,
            'createdAt': '2024-01-01',
            'updatedAt': '2024-01-01',
          }
        }));

    final result = await postbase.storage
        .createBucket('avatars', public: true, fileSizeLimit: 1024);
    expect(result.error, isNull);
    expect(result.data?.id, 'avatars');

    final captured = verify(
      () => client.post(any(),
          headers: any(named: 'headers'), body: captureAny(named: 'body')),
    ).captured;
    final body = jsonDecode(captured.first as String) as Map<String, Object?>;
    expect(body['public'], true);
    expect(body['file_size_limit'], 1024);
  });
}
