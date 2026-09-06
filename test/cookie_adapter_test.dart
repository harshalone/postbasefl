import 'package:mocktail/mocktail.dart';
import 'package:postbase/postbase.dart';
import 'package:test/test.dart';

import 'support/mock_client.dart';

class _SyncCookieAdapter implements CookieAdapter {
  _SyncCookieAdapter(this._cookies);

  final List<Cookie> _cookies;
  List<CookieToSet>? written;

  @override
  List<Cookie> getAll() => _cookies;

  @override
  void setAll(List<CookieToSet> cookies) {
    written = cookies;
  }
}

class _AsyncCookieAdapter implements CookieAdapter {
  _AsyncCookieAdapter(this._cookies);

  final List<Cookie> _cookies;

  @override
  Future<List<Cookie>> getAll() async => _cookies;

  @override
  Future<void> setAll(List<CookieToSet> cookies) async {}
}

void main() {
  setUpAll(registerHttpFallbacks);

  test('sync CookieAdapter forwards session cookie as X-Postbase-Session',
      () async {
    final client = MockClient();
    when(() => client.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => jsonResponse({'data': [], 'count': 0}));

    final adapter = _SyncCookieAdapter(
        [const Cookie(name: 'postbase-session', value: 'refresh-token-123')]);
    final postbase = createClient(
      'https://example.com',
      'pb_anon_test',
      options: PostbaseClientOptions(
          httpClient: client, cookies: adapter, persistSession: false),
    );

    await postbase.from('posts').select();

    final captured = verify(
      () => client.post(any(),
          headers: captureAny(named: 'headers'), body: any(named: 'body')),
    ).captured;
    final headers = captured.first as Map<String, String>;
    expect(headers['X-Postbase-Session'], 'refresh-token-123');
  });

  test('async CookieAdapter forwards session cookie for sql()', () async {
    final client = MockClient();
    when(() => client.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => jsonResponse({'data': [], 'count': 0}));

    final adapter = _AsyncCookieAdapter(
        [const Cookie(name: 'postbase-session', value: 'refresh-token-async')]);
    final postbase = createClient(
      'https://example.com',
      'pb_anon_test',
      options: PostbaseClientOptions(
          httpClient: client, cookies: adapter, persistSession: false),
    );

    await postbase.sql('SELECT 1');

    final captured = verify(
      () => client.post(any(),
          headers: captureAny(named: 'headers'), body: any(named: 'body')),
    ).captured;
    final headers = captured.first as Map<String, String>;
    expect(headers['X-Postbase-Session'], 'refresh-token-async');
  });

  test('setSession writes a postbase-session cookie with the refresh token',
      () async {
    final client = MockClient();
    final adapter = _SyncCookieAdapter([]);
    final postbase = createClient(
      'https://example.com',
      'pb_anon_test',
      options: PostbaseClientOptions(
          httpClient: client, cookies: adapter, persistSession: false),
    );

    const session = Session(
      accessToken: 'at',
      refreshToken: 'rt',
      expiresAt: 9999999999,
      refreshTokenExpiresAt: 9999999999,
      user: AuthUser(id: 'u1', email: 'a@example.com'),
    );

    final error = await postbase.auth.setSession(session);
    expect(error, isNull);
    expect(adapter.written, isNotNull);
    expect(adapter.written!.first.name, 'postbase-session');
    expect(adapter.written!.first.value, 'rt');
  });
}
