/// Admin auth methods — require a service-role key. Bypasses RLS.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../types.dart';

class AuthAdminUsersResult {
  const AuthAdminUsersResult(
      {required this.users, required this.total, required this.error});

  final List<AuthUser>? users;
  final int? total;
  final String? error;
}

class AuthAdminUserResult {
  const AuthAdminUserResult({required this.user, required this.error});

  final AuthUser? user;
  final String? error;
}

class AuthAdminClient {
  AuthAdminClient(this._client, this._baseUrl, this._apiKey, this._projectId,
      this._extraHeaders);

  final http.Client _client;
  final String _baseUrl;
  final String _apiKey;
  final String _projectId;
  final Map<String, String> _extraHeaders;

  String get _adminBase => '$_baseUrl/api/auth/v1/$_projectId/admin/users';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
        ..._extraHeaders,
      };

  /// List all users (service role only).
  Future<AuthAdminUsersResult> listUsers({int? page, int? perPage}) async {
    try {
      final uri = Uri.parse(_adminBase).replace(queryParameters: {
        if (page != null) 'page': '$page',
        if (perPage != null) 'perPage': '$perPage',
      });
      final res = await _client.get(uri, headers: _headers);
      final json = jsonDecode(res.body) as Map<String, Object?>;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return AuthAdminUsersResult(
            users: null,
            total: null,
            error: json['error'] as String? ?? 'Failed to list users');
      }
      final users = ((json['users'] as List?) ?? const [])
          .map((u) => AuthUser.fromJson((u as Map).cast<String, Object?>()))
          .whereType<AuthUser>()
          .toList();
      return AuthAdminUsersResult(
          users: users, total: json['total'] as int?, error: null);
    } catch (err) {
      return AuthAdminUsersResult(
          users: null, total: null, error: err.toString());
    }
  }

  /// Get a user by id (service role only).
  Future<AuthAdminUserResult> getUserById(String id) async {
    try {
      final res =
          await _client.get(Uri.parse('$_adminBase/$id'), headers: _headers);
      final json = jsonDecode(res.body) as Map<String, Object?>;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return AuthAdminUserResult(
            user: null, error: json['error'] as String? ?? 'User not found');
      }
      return AuthAdminUserResult(
          user: AuthUser.fromJson(
              (json['user'] as Map?)?.cast<String, Object?>()),
          error: null);
    } catch (err) {
      return AuthAdminUserResult(user: null, error: err.toString());
    }
  }

  /// Create a user (service role only).
  Future<AuthAdminUserResult> createUser({
    required String email,
    String? password,
    bool? emailConfirm,
    Map<String, Object?>? userMetadata,
  }) async {
    try {
      final res = await _client.post(
        Uri.parse(_adminBase),
        headers: _headers,
        body: jsonEncode({
          'email': email,
          if (password != null) 'password': password,
          if (emailConfirm != null) 'email_confirm': emailConfirm,
          if (userMetadata != null) 'user_metadata': userMetadata,
        }),
      );
      final json = jsonDecode(res.body) as Map<String, Object?>;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return AuthAdminUserResult(
            user: null,
            error: json['error'] as String? ?? 'Failed to create user');
      }
      return AuthAdminUserResult(
          user: AuthUser.fromJson(
              (json['user'] as Map?)?.cast<String, Object?>()),
          error: null);
    } catch (err) {
      return AuthAdminUserResult(user: null, error: err.toString());
    }
  }

  /// Update a user (service role only).
  Future<AuthAdminUserResult> updateUserById(
    String id, {
    String? email,
    String? password,
    Map<String, Object?>? userMetadata,
  }) async {
    try {
      final res = await _client.patch(
        Uri.parse('$_adminBase/$id'),
        headers: _headers,
        body: jsonEncode({
          if (email != null) 'email': email,
          if (password != null) 'password': password,
          if (userMetadata != null) 'user_metadata': userMetadata,
        }),
      );
      final json = jsonDecode(res.body) as Map<String, Object?>;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return AuthAdminUserResult(
            user: null,
            error: json['error'] as String? ?? 'Failed to update user');
      }
      return AuthAdminUserResult(
          user: AuthUser.fromJson(
              (json['user'] as Map?)?.cast<String, Object?>()),
          error: null);
    } catch (err) {
      return AuthAdminUserResult(user: null, error: err.toString());
    }
  }

  /// Delete a user (service role only).
  Future<String?> deleteUser(String id) async {
    try {
      final res =
          await _client.delete(Uri.parse('$_adminBase/$id'), headers: _headers);
      final json = res.body.isEmpty
          ? <String, Object?>{}
          : jsonDecode(res.body) as Map<String, Object?>;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return json['error'] as String? ?? 'Failed to delete user';
      }
      return null;
    } catch (err) {
      return err.toString();
    }
  }
}
