/// OAuth (PKCE) helpers: building the authorize URL and parsing the callback.
///
/// Unlike the browser JS SDK (which redirects `window.location`), Flutter has
/// no single "browser" concept — the caller opens [PostbaseOAuthUrl.url] via
/// `url_launcher` (typically `LaunchMode.externalApplication` or an in-app
/// browser tab) and listens for the deep-link/app-link callback (e.g. with
/// `app_links`), then passes the resulting URL to `handleOAuthCallback`.
library;

import 'dart:convert';

import '../internal/pkce.dart';
import '../types.dart';

/// The result of [buildOAuthAuthorizeUrl]: the URL to open plus the PKCE
/// verifier/state the caller must retain until the callback arrives.
class PostbaseOAuthUrl {
  const PostbaseOAuthUrl(
      {required this.url, required this.codeVerifier, required this.state});

  final String url;
  final String codeVerifier;
  final String state;
}

PostbaseOAuthUrl buildOAuthAuthorizeUrl({
  required String baseUrl,
  required String projectId,
  required String provider,
  String? redirectTo,
  String? scopes,
}) {
  final codeVerifier = generateCodeVerifier();
  final codeChallenge = generateCodeChallenge(codeVerifier);
  final state = generateState();

  final authorizeBase = '$baseUrl/api/auth/v1/$projectId/oauth/authorize';
  final params = <String, String>{
    'provider': provider,
    'code_challenge': codeChallenge,
    'state': state,
    'redirect_to': redirectTo ?? '',
  };
  if (scopes != null) params['scopes'] = scopes;

  final url =
      Uri.parse(authorizeBase).replace(queryParameters: params).toString();
  return PostbaseOAuthUrl(url: url, codeVerifier: codeVerifier, state: state);
}

class OAuthCallbackResult {
  const OAuthCallbackResult(
      {required this.session, required this.user, required this.error});

  final Session? session;
  final AuthUser? user;
  final String? error;
}

/// Parses the query params Postbase appends to the OAuth callback redirect
/// (works for both `https://...` URLs and custom URL schemes like
/// `com.myapp://auth?...`).
OAuthCallbackResult parseOAuthCallback(String callbackUrl) {
  final qIndex = callbackUrl.indexOf('?');
  final query = qIndex >= 0 ? callbackUrl.substring(qIndex + 1) : '';
  final params = Uri.splitQueryString(query);

  final error = params['error'];
  if (error != null) {
    return OAuthCallbackResult(session: null, user: null, error: error);
  }

  final accessToken = params['access_token'];
  final refreshToken = params['refresh_token'];
  final expiresAt = params['expires_at'];
  final refreshTokenExpiresAt = params['refresh_token_expires_at'];
  final userB64 = params['user'];

  if (accessToken == null || refreshToken == null || expiresAt == null) {
    return const OAuthCallbackResult(session: null, user: null, error: null);
  }

  AuthUser? user;
  if (userB64 != null) {
    try {
      final normalized = userB64.replaceAll('-', '+').replaceAll('_', '/');
      final padded = normalized.padRight((normalized.length + 3) ~/ 4 * 4, '=');
      final decoded = utf8.decode(base64.decode(padded));
      user = AuthUser.fromJson(jsonDecode(decoded) as Map<String, Object?>);
    } catch (_) {
      user = null;
    }
  }

  final session = Session(
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresAt: num.tryParse(expiresAt) ?? 0,
    refreshTokenExpiresAt: refreshTokenExpiresAt != null
        ? num.tryParse(refreshTokenExpiresAt)
        : null,
    user: user ?? const AuthUser(id: '', email: ''),
  );

  return OAuthCallbackResult(session: session, user: user, error: null);
}
