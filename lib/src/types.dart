/// Shared types for the Postbase Dart client.
library;

import 'dart:async';

// ─── Filters ────────────────────────────────────────────────────────────────

/// Operators supported by the `/api/db/query` filter array.
enum FilterOperator {
  eq,
  neq,
  gt,
  gte,
  lt,
  lte,
  like,
  ilike,
  in_,
  is_,
  contains,
  overlaps,
  textSearch;

  /// The wire value sent to the server (`in_`/`is_` become `in`/`is`,
  /// `textSearch` stays camelCase to match the JS/Python SDKs).
  String get wire {
    switch (this) {
      case FilterOperator.in_:
        return 'in';
      case FilterOperator.is_:
        return 'is';
      default:
        return name;
    }
  }
}

/// A single structured filter: `column operator value`.
class Filter {
  const Filter(
      {required this.column, required this.operator, required this.value});

  final String column;
  final FilterOperator operator;
  final Object? value;

  Map<String, Object?> toJson() => {
        'column': column,
        'operator': operator.wire,
        'value': value,
      };

  @override
  bool operator ==(Object other) =>
      other is Filter &&
      other.column == column &&
      other.operator == operator &&
      _valueEquals(other.value, value);

  @override
  int get hashCode => Object.hash(column, operator, _hashValue(value));
}

bool _valueEquals(Object? a, Object? b) {
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_valueEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

int _hashValue(Object? v) =>
    v is List ? Object.hashAll(v.map(_hashValue)) : v.hashCode;

// ─── Join ───────────────────────────────────────────────────────────────────

enum JoinType {
  inner,
  left,
  right,
  full;
}

class JoinClause {
  const JoinClause({required this.table, required this.on, this.type});

  final String table;
  final String on;
  final JoinType? type;

  Map<String, Object?> toJson() => {
        'table': table,
        'on': on,
        if (type != null) 'type': type!.name,
      };
}

// ─── Order ──────────────────────────────────────────────────────────────────

class OrderBy {
  const OrderBy({required this.column, this.ascending, this.nullsFirst});

  final String column;
  final bool? ascending;
  final bool? nullsFirst;

  Map<String, Object?> toJson() => {
        'column': column,
        if (ascending != null) 'ascending': ascending,
        if (nullsFirst != null) 'nullsFirst': nullsFirst,
      };
}

// ─── Results ────────────────────────────────────────────────────────────────

/// Result of a multi-row query (`select`, `insert`, `update`, `delete`, `upsert`).
class QueryResult<T> {
  const QueryResult(
      {required this.data, required this.count, required this.error});

  final List<T>? data;
  final int? count;
  final String? error;
}

/// Result of a single-row query (`.single()` / `.maybeSingle()`).
class SingleResult<T> {
  const SingleResult({required this.data, required this.error});

  final T? data;
  final String? error;
}

// ─── Auth ───────────────────────────────────────────────────────────────────

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.name,
    this.image,
    this.emailVerified,
    this.phone,
    this.role,
    this.metadata = const {},
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String email;
  final String? name;
  final String? image;
  final bool? emailVerified;
  final String? phone;
  final String? role;
  final Map<String, Object?> metadata;
  final String? createdAt;
  final String? updatedAt;

  static AuthUser? fromJson(Map<String, Object?>? json) {
    if (json == null) return null;
    return AuthUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String?,
      image: json['image'] as String?,
      emailVerified: json['emailVerified'] as bool?,
      phone: json['phone'] as String?,
      role: json['role'] as String?,
      metadata: (json['metadata'] as Map?)?.cast<String, Object?>() ?? const {},
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'image': image,
        'emailVerified': emailVerified,
        'phone': phone,
        'role': role,
        'metadata': metadata,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}

class Session {
  const Session({
    required this.accessToken,
    required this.expiresAt,
    this.refreshToken,
    this.refreshTokenExpiresAt,
    this.user,
  });

  final String accessToken;

  /// Access-token expiry, unix seconds.
  final num expiresAt;
  final String? refreshToken;

  /// Refresh-token expiry, unix seconds — drives cookie/storage maxAge.
  final num? refreshTokenExpiresAt;
  final AuthUser? user;

  static Session? fromJson(Map<String, Object?>? json) {
    if (json == null) return null;
    return Session(
      accessToken: json['accessToken'] as String? ?? '',
      expiresAt: json['expiresAt'] as num? ?? 0,
      refreshToken: json['refreshToken'] as String?,
      refreshTokenExpiresAt: json['refreshTokenExpiresAt'] as num?,
      user: AuthUser.fromJson((json['user'] as Map?)?.cast<String, Object?>()),
    );
  }

  Map<String, Object?> toJson() => {
        'accessToken': accessToken,
        'expiresAt': expiresAt,
        'refreshToken': refreshToken,
        'refreshTokenExpiresAt': refreshTokenExpiresAt,
        'user': user?.toJson(),
      };
}

class AuthResponse {
  const AuthResponse(
      {required this.user, required this.session, required this.error});

  final AuthUser? user;
  final Session? session;
  final String? error;
}

/// Providers that support the native id_token flow (Apple native SDK, Google Sign-In).
enum NativeOAuthProvider {
  apple,
  google;
}

/// Auth state change events, mirroring the JS/Python SDKs.
enum AuthChangeEvent {
  signedIn,
  signedOut,
  tokenRefreshed,
  userUpdated,
}

// ─── Storage ────────────────────────────────────────────────────────────────

class StorageObject {
  const StorageObject({
    required this.name,
    required this.size,
    required this.contentType,
    required this.updatedAt,
    required this.createdAt,
  });

  final String name;
  final int size;
  final String contentType;
  final String updatedAt;
  final String createdAt;

  static StorageObject fromJson(Map<String, Object?> json) => StorageObject(
        name: json['name'] as String? ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        contentType: json['contentType'] as String? ?? '',
        updatedAt: json['updatedAt'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '',
      );
}

class Bucket {
  const Bucket({
    required this.id,
    required this.name,
    required this.public,
    required this.createdAt,
    required this.updatedAt,
    this.fileSizeLimit,
    this.allowedMimeTypes,
  });

  final String id;
  final String name;
  final bool public;
  final String createdAt;
  final String updatedAt;
  final int? fileSizeLimit;
  final List<String>? allowedMimeTypes;

  static Bucket fromJson(Map<String, Object?> json) => Bucket(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        public: json['public'] as bool? ?? false,
        createdAt: json['createdAt'] as String? ?? '',
        updatedAt: json['updatedAt'] as String? ?? '',
        fileSizeLimit: (json['fileSizeLimit'] as num?)?.toInt(),
        allowedMimeTypes: (json['allowedMimeTypes'] as List?)?.cast<String>(),
      );
}

// ─── RPC ────────────────────────────────────────────────────────────────────

class RpcOptions {
  const RpcOptions({this.head = false, this.count});

  final bool head;

  /// `exact`, `planned`, or `estimated`.
  final String? count;
}

// ─── Email ──────────────────────────────────────────────────────────────────

class EmailSendOptions {
  const EmailSendOptions({
    required this.to,
    required this.subject,
    this.text,
    this.html,
    this.replyTo,
  });

  final String to;
  final String subject;
  final String? text;
  final String? html;
  final String? replyTo;
}

// ─── Cookies (Dart backend / SSR use) ────────────────────────────────────────

/// A cookie as read from the host framework's request.
class Cookie {
  const Cookie({required this.name, required this.value});

  final String name;
  final String value;
}

/// A cookie to be set on the host framework's response.
class CookieToSet {
  const CookieToSet(
      {required this.name, required this.value, this.options = const {}});

  final String name;
  final String value;
  final Map<String, Object?> options;
}

/// Bridges Postbase session cookies to a Dart server framework's
/// request/response (e.g. `shelf`, `dart_frog`). Not relevant for Flutter
/// apps — those have no server-rendered request/response cycle.
abstract class CookieAdapter {
  /// May be sync or async.
  FutureOr<List<Cookie>> getAll();

  /// May be sync or async.
  FutureOr<void> setAll(List<CookieToSet> cookies);
}
