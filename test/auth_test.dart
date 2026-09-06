import 'package:mocktail/mocktail.dart';
import 'package:postbase/postbase.dart';
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

  test('signUp returns session and user', () async {
    when(() => client.post(
          Uri.parse('https://example.com/api/auth/v1/proj1/signup'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => jsonResponse({
          'user': {'id': 'u1', 'email': 'a@example.com'},
          'session': {
            'accessToken': 'at',
            'refreshToken': 'rt',
            'expiresAt': 9999999999,
            'user': {'id': 'u1', 'email': 'a@example.com'},
          },
        }));

    final response = await postbase.auth
        .signUp(email: 'a@example.com', password: 'supersecret');
    expect(response.error, isNull);
    expect(response.user?.id, 'u1');
    expect(response.session?.accessToken, 'at');
  });

  test('signInWithPassword surfaces error', () async {
    when(() => client.post(
              Uri.parse('https://example.com/api/auth/v1/proj1/token'),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ))
        .thenAnswer((_) async =>
            jsonResponse({'error': 'invalid credentials'}, statusCode: 400));

    final response = await postbase.auth
        .signInWithPassword(email: 'a@example.com', password: 'wrong');
    expect(response.error, 'invalid credentials');
    expect(response.user, isNull);
  });

  test('signInWithOAuth builds a PKCE authorize url', () {
    final result = postbase.auth.signInWithOAuth(
        provider: 'google', redirectTo: 'https://app.com/callback');
    expect(result.url, contains('code_challenge='));
    expect(result.url, contains('state='));
    expect(result.url, contains('provider=google'));
    expect(result.codeVerifier, isNotEmpty);
    expect(result.url, contains(result.state));
  });

  test('handleOAuthCallback parses tokens from the callback url', () async {
    const callbackUrl =
        'https://app.com/callback?access_token=at&refresh_token=rt'
        '&expires_at=9999999999&refresh_token_expires_at=8888888888';

    final response = await postbase.auth.handleOAuthCallback(callbackUrl);
    expect(response.error, isNull);
    expect(response.session?.accessToken, 'at');
    expect(response.session?.refreshToken, 'rt');
    expect(response.session?.refreshTokenExpiresAt, 8888888888);
  });

  test('handleOAuthCallback surfaces an error param', () async {
    final response = await postbase.auth
        .handleOAuthCallback('https://app.com/callback?error=access_denied');
    expect(response.error, 'access_denied');
    expect(response.session, isNull);
  });

  test('admin.listUsers requires service key but works with any key here',
      () async {
    when(() => client.get(
          Uri.parse(
              'https://example.com/api/auth/v1/proj1/admin/users?page=1&perPage=50'),
          headers: any(named: 'headers'),
        )).thenAnswer((_) async => jsonResponse({
          'users': [
            {'id': 'u1', 'email': 'a@example.com'}
          ],
          'total': 1,
        }));

    final result = await postbase.auth.admin.listUsers(page: 1, perPage: 50);
    expect(result.error, isNull);
    expect(result.total, 1);
    expect(result.users?.first.id, 'u1');
  });

  test('verifyOtp notifies onAuthStateChange with signedIn', () async {
    when(() => client.post(
          Uri.parse('https://example.com/api/auth/v1/proj1/verify'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => jsonResponse({
          'user': {'id': 'u1', 'email': 'a@example.com'},
          'session': {
            'accessToken': 'at',
            'refreshToken': 'rt',
            'expiresAt': 9999999999,
            'user': {'id': 'u1', 'email': 'a@example.com'},
          },
        }));

    final events = <AuthChangeEvent>[];
    final sub = postbase.auth.onAuthStateChange
        .listen((change) => events.add(change.event));

    await postbase.auth.verifyOtp(email: 'a@example.com', token: '123456');
    await Future<void>.delayed(Duration.zero);

    expect(events, contains(AuthChangeEvent.signedIn));
    await sub.cancel();
  });

  test('setRememberMe fails without an active session', () async {
    final response = await postbase.auth.setRememberMe(true);
    expect(response.error, 'No active session');
  });
}
