## 0.1.1

- No library changes. Adds a GitHub Actions workflow that publishes to pub.dev
  automatically via OIDC when a `v<version>` tag is pushed — this release
  validates that pipeline end-to-end.

## 0.1.0

Initial release — Dart/Flutter port of [postbasejs](https://www.npmjs.com/package/postbasejs).

- Query builder: select/insert/upsert/update/delete, all filter methods, `.or()`/`.not()`,
  joins with column-alias remapping, `.single()`/`.maybeSingle()`, limit/offset/range, count option.
- Auth client: password, magic link, OTP, email OTP, native id-token (Apple/Google), OAuth
  (PKCE, deep-link based), remember-me, `onAuthStateChange` as a `Stream`, admin methods.
- Storage client: upload (`Uint8List` / `dart:io File`), download, remove, list, public/signed
  URLs, move/copy, bucket management.
- Email client.
- Raw SQL (`postbase.sql`) with positional `$1`/`$2` params.
- RPC (`postbase.rpc`).
- Session persistence via `shared_preferences` (metadata) + `flutter_secure_storage` (refresh token).
- `CookieAdapter` for Dart backend (shelf/dart_frog) session forwarding.
- Realtime (WebSocket subscriptions) is not yet implemented — planned as a future addition.
