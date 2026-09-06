/// Auth client — `/api/auth/v1/{projectId}/...`.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../internal/session_storage.dart';
import '../types.dart';
import 'auth_admin_client.dart';
import 'oauth.dart';

/// An event + the session at the time it fired, delivered on
/// [AuthClient.onAuthStateChange].
class AuthStateChange {
  const AuthStateChange(this.event, this.session);

  final AuthChangeEvent event;
  final Session? session;
}

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

class AuthClient {
  AuthClient({
    required http.Client client,
    required String baseUrl,
    required String apiKey,
    required String projectId,
    Map<String, String>? extraHeaders,
    CookieAdapter? cookieAdapter,
    SessionStorage? sessionStorage,
    bool persistSession = true,
    bool autoRefreshToken = true,
  })  : _client = client,
        _baseUrl = baseUrl,
        _apiKey = apiKey,
        _projectId = projectId,
        _extraHeaders = extraHeaders ?? const {},
        _cookieAdapter = cookieAdapter,
        _sessionStorage = sessionStorage,
        _persistSession = persistSession,
        _autoRefreshToken = autoRefreshToken,
        admin = AuthAdminClient(
            client, baseUrl, apiKey, projectId, extraHeaders ?? const {});

  final http.Client _client;
  final String _baseUrl;
  final String _apiKey;
  final String _projectId;
  final Map<String, String> _extraHeaders;
  final CookieAdapter? _cookieAdapter;
  final SessionStorage? _sessionStorage;
  final bool _persistSession;
  final bool _autoRefreshToken;

  final AuthAdminClient admin;

  final StreamController<AuthStateChange> _controller =
      StreamController<AuthStateChange>.broadcast();
  Session? _currentSession;
  Timer? _refreshTimer;
  final Map<String, String> _pkceVerifiers = {};

  String get _authBase => '$_baseUrl/api/auth/v1/$_projectId';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
        ..._extraHeaders,
      };

  /// Auth state change events: `signedIn`, `signedOut`, `tokenRefreshed`, `userUpdated`.
  Stream<AuthStateChange> get onAuthStateChange => _controller.stream;

  void _notify(AuthChangeEvent event, Session? session) {
    _currentSession = session;
    if (_persistSession && _sessionStorage != null) {
      if (session != null) {
        unawaited(_sessionStorage.save(session));
      } else {
        unawaited(_sessionStorage.clear());
      }
    }
    if (session != null) _scheduleRefresh(session);
    _controller.add(AuthStateChange(event, session));
  }

  void _scheduleRefresh(Session session) {
    if (!_autoRefreshToken) return;
    _refreshTimer?.cancel();
    final expiresInSeconds =
        session.expiresAt - DateTime.now().millisecondsSinceEpoch / 1000;
    final refreshInSeconds = (expiresInSeconds - 60).clamp(0, double.infinity);
    _refreshTimer = Timer(
        Duration(milliseconds: (refreshInSeconds * 1000).round()), () async {
      if (session.refreshToken != null) {
        final result = await refreshSession(session.refreshToken);
        if (result.error == null && result.session != null) {
          _notify(AuthChangeEvent.tokenRefreshed, result.session);
        }
      }
    });
  }

  /// Restores a previously persisted session (call once at startup if you
  /// constructed the client with session persistence enabled).
  Future<Session?> restoreSession() async {
    if (!_persistSession || _sessionStorage == null) return null;
    final session = await _sessionStorage.load();
    if (session == null) return null;
    if (session.expiresAt > 0 &&
        DateTime.now().millisecondsSinceEpoch / 1000 > session.expiresAt) {
      // Access token expired — still usable via refreshToken by the caller.
      _currentSession = session;
      return session;
    }
    _currentSession = session;
    _scheduleRefresh(session);
    return session;
  }

  // ─── Sign-up / sign-in ──────────────────────────────────────────────────

  /// Sign up with email + password.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    bool? rememberMe,
    Map<String, Object?>? data,
  }) async {
    try {
      final res = await _client.post(
        Uri.parse('$_authBase/signup'),
        headers: _headers,
        body: jsonEncode({
          'email': email,
          'password': password,
          'data': data,
          'remember_me': rememberMe
        }),
      );
      final json = _decode(res);
      if (!_ok(res)) {
        return AuthResponse(
            user: null,
            session: null,
            error: json['error'] as String? ?? 'Sign up failed');
      }
      final session =
          Session.fromJson((json['session'] as Map?)?.cast<String, Object?>());
      final user =
          AuthUser.fromJson((json['user'] as Map?)?.cast<String, Object?>());
      if (session != null) _notify(AuthChangeEvent.signedIn, session);
      return AuthResponse(user: user, session: session, error: null);
    } catch (err) {
      return AuthResponse(user: null, session: null, error: err.toString());
    }
  }

  /// Sign in with email + password.
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
    bool? rememberMe,
  }) async {
    try {
      final res = await _client.post(
        Uri.parse('$_authBase/token'),
        headers: _headers,
        body: jsonEncode({
          'email': email,
          'password': password,
          'grant_type': 'password',
          'remember_me': rememberMe
        }),
      );
      final json = _decode(res);
      if (!_ok(res)) {
        return AuthResponse(
            user: null,
            session: null,
            error: json['error'] as String? ?? 'Sign in failed');
      }
      final session =
          Session.fromJson((json['session'] as Map?)?.cast<String, Object?>());
      final user =
          AuthUser.fromJson((json['user'] as Map?)?.cast<String, Object?>());
      _notify(AuthChangeEvent.signedIn, session);
      return AuthResponse(user: user, session: session, error: null);
    } catch (err) {
      return AuthResponse(user: null, session: null, error: err.toString());
    }
  }

  /// Send a magic link (`type: 'magic_link'`) or 6-digit OTP (`type: 'otp'`) to email.
  Future<String?> signInWithOtp({
    required String email,
    String type = 'otp',
    String? redirectTo,
  }) async {
    try {
      final res = await _client.post(
        Uri.parse('$_authBase/otp'),
        headers: _headers,
        body: jsonEncode(
            {'email': email, 'type': type, 'redirectTo': redirectTo}),
      );
      final json = _decode(res);
      if (!_ok(res)) return json['error'] as String? ?? 'OTP send failed';
      return null;
    } catch (err) {
      return err.toString();
    }
  }

  /// Verify a 6-digit OTP code sent via [signInWithOtp].
  Future<AuthResponse> verifyOtp(
      {required String email, required String token, bool? rememberMe}) async {
    try {
      final res = await _client.post(
        Uri.parse('$_authBase/verify'),
        headers: _headers,
        body: jsonEncode(
            {'email': email, 'token': token, 'remember_me': rememberMe}),
      );
      final json = _decode(res);
      if (!_ok(res)) {
        return AuthResponse(
            user: null,
            session: null,
            error: json['error'] as String? ?? 'Verification failed');
      }
      final session =
          Session.fromJson((json['session'] as Map?)?.cast<String, Object?>());
      final user =
          AuthUser.fromJson((json['user'] as Map?)?.cast<String, Object?>());
      _notify(AuthChangeEvent.signedIn, session);
      return AuthResponse(user: user, session: session, error: null);
    } catch (err) {
      return AuthResponse(user: null, session: null, error: err.toString());
    }
  }

  /// Sign in with a native provider id_token (Apple Sign In, Google Sign-In).
  /// Use for iOS/macOS/Android apps where the OS hands you an id_token
  /// directly — no browser redirect needed.
  Future<AuthResponse> signInWithIdToken({
    required NativeOAuthProvider provider,
    required String idToken,
    String? nonce,
    bool? rememberMe,
  }) async {
    try {
      final res = await _client.post(
        Uri.parse('$_authBase/oauth/id-token'),
        headers: _headers,
        body: jsonEncode({
          'provider': provider.name,
          'id_token': idToken,
          'nonce': nonce,
          'remember_me': rememberMe
        }),
      );
      final json = _decode(res);
      if (!_ok(res)) {
        return AuthResponse(
            user: null,
            session: null,
            error: json['error'] as String? ?? 'Sign in failed');
      }
      final session =
          Session.fromJson((json['session'] as Map?)?.cast<String, Object?>());
      final user =
          AuthUser.fromJson((json['user'] as Map?)?.cast<String, Object?>());
      _notify(AuthChangeEvent.signedIn, session);
      return AuthResponse(user: user, session: session, error: null);
    } catch (err) {
      return AuthResponse(user: null, session: null, error: err.toString());
    }
  }

  // ─── OAuth (PKCE, redirect-based) ───────────────────────────────────────

  /// Builds the provider authorize URL for a PKCE OAuth flow.
  ///
  /// Flutter has no `window.location` to redirect automatically — open
  /// [PostbaseOAuthUrl.url] yourself (typically via `url_launcher`, e.g.
  /// `launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)`) and
  /// listen for the deep-link/app-link callback (e.g. with `app_links`).
  /// Pass the resulting callback URL to [handleOAuthCallback].
  PostbaseOAuthUrl signInWithOAuth(
      {required String provider, String? redirectTo, String? scopes}) {
    final result = buildOAuthAuthorizeUrl(
      baseUrl: _baseUrl,
      projectId: _projectId,
      provider: provider,
      redirectTo: redirectTo,
      scopes: scopes,
    );
    _pkceVerifiers[result.state] = result.codeVerifier;
    return result;
  }

  /// Call after the OAuth provider redirects back to your app (deep link /
  /// app link / custom URL scheme) to parse tokens and store the session.
  Future<AuthResponse> handleOAuthCallback(String callbackUrl) async {
    final result = parseOAuthCallback(callbackUrl);
    if (result.error != null) {
      return AuthResponse(user: null, session: null, error: result.error);
    }
    if (result.session == null) {
      return const AuthResponse(user: null, session: null, error: null);
    }
    _notify(AuthChangeEvent.signedIn, result.session);
    return AuthResponse(
        user: result.user, session: result.session, error: null);
  }

  // ─── Session / user ─────────────────────────────────────────────────────

  /// Sign out the current user.
  Future<String?> signOut() async {
    try {
      final session = _currentSession ?? await _sessionStorage?.load();
      final headers = {
        ..._headers,
        if (session != null) 'X-Postbase-Token': session.accessToken
      };
      await _client.post(Uri.parse('$_authBase/logout'), headers: headers);
      _refreshTimer?.cancel();
      _notify(AuthChangeEvent.signedOut, null);
      return null;
    } catch (err) {
      return err.toString();
    }
  }

  /// Get the current session (from cookie adapter, persisted storage, or the server).
  Future<Session?> getSession() async {
    if (_cookieAdapter != null) {
      final cookies = await _resolveFutureOr(_cookieAdapter.getAll());
      final sessionCookie = _findSessionCookie(cookies);
      if (sessionCookie == null) return null;
      final res = await _client.get(
        Uri.parse('$_authBase/session'),
        headers: {..._headers, 'X-Postbase-Session': sessionCookie.value},
      );
      if (!_ok(res)) return null;
      final json = _decode(res);
      return Session.fromJson(
          (json['session'] as Map?)?.cast<String, Object?>());
    }

    if (_currentSession != null) return _currentSession;

    if (_sessionStorage != null) {
      final persisted = await _sessionStorage.load();
      if (persisted != null) {
        _currentSession = persisted;
        return persisted;
      }
    }

    final res =
        await _client.get(Uri.parse('$_authBase/session'), headers: _headers);
    if (!_ok(res)) return null;
    final json = _decode(res);
    return Session.fromJson((json['session'] as Map?)?.cast<String, Object?>());
  }

  /// Get the current user (server-verified).
  Future<AuthUser?> getUser([String? jwt]) async {
    var token = jwt;
    if (token == null && _cookieAdapter != null) {
      final session = await getSession();
      token = session?.accessToken;
      if (token == null) return null;
    } else {
      token ??= _currentSession?.accessToken ??
          (await _sessionStorage?.load())?.accessToken;
    }
    final res = await _client.get(
      Uri.parse('$_authBase/user'),
      headers: {..._headers, if (token != null) 'X-Postbase-Token': token},
    );
    if (!_ok(res)) return null;
    final json = _decode(res);
    return AuthUser.fromJson((json['user'] as Map?)?.cast<String, Object?>());
  }

  /// Update the current authenticated user's profile.
  Future<AuthUser?> updateUser(
      {String? name, String? image, Map<String, Object?>? data}) async {
    final token = _currentSession?.accessToken ??
        (await _sessionStorage?.load())?.accessToken;
    final res = await _client.patch(
      Uri.parse('$_authBase/user'),
      headers: {..._headers, if (token != null) 'X-Postbase-Token': token},
      body: jsonEncode({
        if (name != null) 'name': name,
        if (image != null) 'image': image,
        if (data != null) 'data': data,
      }),
    );
    if (!_ok(res)) return null;
    final json = _decode(res);
    _notify(AuthChangeEvent.userUpdated, _currentSession);
    return AuthUser.fromJson((json['user'] as Map?)?.cast<String, Object?>());
  }

  /// Send a 6-digit OTP code to email via `/email-otp`.
  Future<String?> signInWithEmailOtp(String email) async {
    try {
      final res = await _client.post(
        Uri.parse('$_authBase/email-otp'),
        headers: _headers,
        body: jsonEncode({'email': email}),
      );
      final json = _decode(res);
      if (!_ok(res)) return json['error'] as String? ?? 'Email OTP send failed';
      return null;
    } catch (err) {
      return err.toString();
    }
  }

  /// Verify a 6-digit email OTP code sent via [signInWithEmailOtp].
  Future<AuthResponse> verifyEmailOtp(
      {required String email, required String code, bool? rememberMe}) async {
    try {
      final res = await _client.post(
        Uri.parse('$_authBase/email-otp/verify'),
        headers: _headers,
        body: jsonEncode(
            {'email': email, 'code': code, 'remember_me': rememberMe}),
      );
      final json = _decode(res);
      if (!_ok(res)) {
        return AuthResponse(
            user: null,
            session: null,
            error: json['error'] as String? ?? 'Verification failed');
      }
      final session =
          Session.fromJson((json['session'] as Map?)?.cast<String, Object?>());
      final user =
          AuthUser.fromJson((json['user'] as Map?)?.cast<String, Object?>());
      _notify(AuthChangeEvent.signedIn, session);
      return AuthResponse(user: user, session: session, error: null);
    } catch (err) {
      return AuthResponse(user: null, session: null, error: err.toString());
    }
  }

  /// Refresh the session using a refresh token.
  Future<AuthResponse> refreshSession([String? refreshToken]) async {
    try {
      final token = refreshToken ??
          _currentSession?.refreshToken ??
          (await _sessionStorage?.load())?.refreshToken;
      final res = await _client.post(
        Uri.parse('$_authBase/token'),
        headers: _headers,
        body:
            jsonEncode({'refresh_token': token, 'grant_type': 'refresh_token'}),
      );
      final json = _decode(res);
      if (!_ok(res)) {
        return AuthResponse(
            user: null,
            session: null,
            error: json['error'] as String? ?? 'Refresh failed');
      }
      final session =
          Session.fromJson((json['session'] as Map?)?.cast<String, Object?>());
      final user =
          AuthUser.fromJson((json['user'] as Map?)?.cast<String, Object?>());
      _notify(AuthChangeEvent.tokenRefreshed, session);
      return AuthResponse(user: user, session: session, error: null);
    } catch (err) {
      return AuthResponse(user: null, session: null, error: err.toString());
    }
  }

  /// Update the remember-me state of the current session, re-issuing the
  /// refresh token with the corresponding TTL (30 days if `true`, 7 if
  /// `false`). Works regardless of how the session was created — use this
  /// after an OAuth sign-in, since OAuth has no request body to carry the
  /// flag at sign-in time.
  Future<AuthResponse> setRememberMe(bool rememberMe) async {
    try {
      final token = _currentSession?.refreshToken ??
          (await _sessionStorage?.load())?.refreshToken;
      if (token == null) {
        return const AuthResponse(
            user: null, session: null, error: 'No active session');
      }
      final res = await _client.patch(
        Uri.parse('$_authBase/session'),
        headers: _headers,
        body: jsonEncode({'refresh_token': token, 'remember_me': rememberMe}),
      );
      final json = _decode(res);
      if (!_ok(res)) {
        return AuthResponse(
            user: null,
            session: null,
            error: json['error'] as String? ?? 'Update failed');
      }
      final session =
          Session.fromJson((json['session'] as Map?)?.cast<String, Object?>());
      _notify(AuthChangeEvent.tokenRefreshed, session);
      return AuthResponse(user: session?.user, session: session, error: null);
    } catch (err) {
      return AuthResponse(user: null, session: null, error: err.toString());
    }
  }

  /// Persist a session obtained outside the SDK (e.g. forwarded from a
  /// server-side OAuth callback route). Updates in-memory/persisted state
  /// and — when a [CookieAdapter] is present — writes a `postbase-session`
  /// cookie so subsequent requests through that adapter are authenticated.
  Future<String?> setSession(Session session) async {
    if (session.accessToken.isEmpty || session.refreshToken == null) {
      return 'Invalid session: accessToken and refreshToken are required';
    }
    _notify(AuthChangeEvent.signedIn, session);
    if (_cookieAdapter != null) {
      final nowSeconds = DateTime.now().millisecondsSinceEpoch / 1000;
      final maxAge = session.refreshTokenExpiresAt != null
          ? (session.refreshTokenExpiresAt! - nowSeconds)
              .clamp(0, double.infinity)
              .round()
          : 7 * 24 * 60 * 60;
      await _resolveFutureOr(_cookieAdapter.setAll([
        CookieToSet(
          name: 'postbase-session',
          value: session.refreshToken!,
          options: {
            'httpOnly': true,
            'secure': true,
            'sameSite': 'lax',
            'maxAge': maxAge,
            'path': '/',
          },
        ),
      ]));
    }
    return null;
  }

  void dispose() {
    _refreshTimer?.cancel();
    unawaited(_controller.close());
  }

  Map<String, Object?> _decode(http.Response res) {
    if (res.body.isEmpty) return const {};
    return jsonDecode(res.body) as Map<String, Object?>;
  }

  bool _ok(http.Response res) => res.statusCode >= 200 && res.statusCode < 300;

  Future<T> _resolveFutureOr<T>(Object? value) async {
    if (value is Future<T>) return await value;
    return value as T;
  }
}
