/// PKCE helpers for the OAuth authorization-code flow. Not part of the public API.
library;

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

final Random _random = Random.secure();

String _base64UrlEncode(List<int> bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}

List<int> _randomBytes(int length) {
  return List<int>.generate(length, (_) => _random.nextInt(256));
}

String generateCodeVerifier() => _base64UrlEncode(_randomBytes(32));

String generateCodeChallenge(String verifier) {
  final digest = sha256.convert(utf8.encode(verifier));
  return _base64UrlEncode(digest.bytes);
}

String generateState() => _base64UrlEncode(_randomBytes(16));
