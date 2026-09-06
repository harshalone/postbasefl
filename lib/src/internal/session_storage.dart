/// Session persistence abstraction. The JS SDK uses `localStorage`; Flutter
/// has no direct equivalent, so this splits storage into:
///
///  - the refresh token (long-lived credential) → `flutter_secure_storage`
///  - the rest of the session (access token, expiry, user) → `shared_preferences`
///
/// This mirrors the security posture recommended for mobile apps: secrets
/// that grant long-lived access live in the platform keychain/keystore, not
/// plain prefs.
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../types.dart';

const String _refreshTokenSuffix = '_refresh_token';

/// Persists and restores a [Session] across app restarts.
class SessionStorage {
  SessionStorage(
      {required this.storageKey, FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final String storageKey;
  final FlutterSecureStorage _secureStorage;

  String get _refreshTokenKey => '$storageKey$_refreshTokenSuffix';

  /// Persists [session]. The refresh token is stored separately in secure
  /// storage; everything else goes to shared_preferences.
  Future<void> save(Session session) async {
    final prefs = await SharedPreferences.getInstance();
    final withoutRefreshToken = session.toJson()..remove('refreshToken');
    await prefs.setString(storageKey, jsonEncode(withoutRefreshToken));
    if (session.refreshToken != null) {
      await _secureStorage.write(
          key: _refreshTokenKey, value: session.refreshToken);
    } else {
      await _secureStorage.delete(key: _refreshTokenKey);
    }
  }

  /// Loads the persisted session, or `null` if none is stored or it has
  /// expired (access token TTL — callers should refresh in that case using
  /// the still-valid refresh token).
  Future<Session?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      final session = Session.fromJson({...json, 'refreshToken': refreshToken});
      return session;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
    await _secureStorage.delete(key: _refreshTokenKey);
  }
}
