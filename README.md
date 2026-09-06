# postbase

The official Dart/Flutter client for [Postbase](https://www.getpostbase.com) — a self-hosted, open-source backend as a service.

[![pub package](https://img.shields.io/pub/v/postbase)](https://pub.dev/packages/postbase)
[![license](https://img.shields.io/github/license/harshalone/postbase-sdk-flutter)](https://github.com/harshalone/postbase-sdk-flutter/blob/main/LICENSE)

> **[getpostbase.com](https://www.getpostbase.com)** · [Documentation](https://www.getpostbase.com/docs) · [GitHub](https://github.com/harshalone/postbase-sdk-flutter)

---

<p align="center">
  <a href="https://www.youtube.com/watch?v=St_kJZXZ_nE">
    <img src="https://img.youtube.com/vi/St_kJZXZ_nE/maxresdefault.jpg" alt="Postbase overview video" width="100%" />
  </a>
  <br/><em>▶ Watch: Postbase overview</em>
</p>

---

## What is Postbase?

Postbase is a self-hosted backend platform built on PostgreSQL. It gives you a database with a REST query API, authentication (password, magic link, OTP, OAuth), file storage, and row-level security — all running on your own infrastructure.

`postbase` is the Dart/Flutter client SDK for interacting with your Postbase instance — the same chainable query builder as [`postbasejs`](https://www.npmjs.com/package/postbasejs) and [`postbasepy`](https://pypi.org/project/postbasepy/), idiomatic to Dart, and working in Flutter (iOS, Android, web, desktop) as well as plain Dart (server-side, CLI).

---

## Screenshots

<p align="center">
  <img src="https://raw.githubusercontent.com/harshalone/postbase/main/images/1.png" alt="Postbase landing" width="100%" />
  <br/><em>Self-hosted auth + database platform for Next.js</em>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/harshalone/postbase/main/images/2.png" alt="Dashboard" width="100%" />
  <br/><em>Dashboard — manage organisations and projects</em>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/harshalone/postbase/main/images/3.png" alt="Project overview" width="100%" />
  <br/><em>Project overview with quick-start guide</em>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/harshalone/postbase/main/images/4.png" alt="Auth providers" width="100%" />
  <br/><em>25+ auth providers — toggle any from the dashboard</em>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/harshalone/postbase/main/images/5.png" alt="SQL editor" width="100%" />
  <br/><em>Built-in SQL editor with AI query generation</em>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/harshalone/postbase/main/images/6.png" alt="Storage connections" width="100%" />
  <br/><em>S3-compatible storage — connect Amazon S3, Cloudflare R2, Backblaze B2, and more</em>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/harshalone/postbase/main/images/7.png" alt="Cron jobs" width="100%" />
  <br/><em>Scheduled cron jobs — run SQL snippets or HTTP requests on any schedule</em>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/harshalone/postbase/main/images/8.png" alt="API keys" width="100%" />
  <br/><em>API keys — anon and service role keys with SDK snippet</em>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/harshalone/postbase/main/images/9.png" alt="Project settings" width="100%" />
  <br/><em>Project settings — configure auth redirect URLs, JWT expiry, and more</em>
</p>

---

## Installation

```bash
flutter pub add postbase
# or, for a plain Dart project (server-side / CLI):
dart pub add postbase
```

Works in Flutter (iOS, Android, web, macOS, Windows, Linux) and plain Dart. Built on [`package:http`](https://pub.dev/packages/http), so it runs anywhere Dart runs.

---

## Quick Start

```dart
import 'package:postbase/postbase.dart';

final postbase = createClient(
  'https://your-postbase-instance.com',
  'pb_anon_your_api_key',
  options: const PostbaseClientOptions(projectId: 'your-project-id'),
);

final result = await postbase.from('posts').select();
print(result.data);
print(result.error);
```

Your **URL**, **anon key**, and **project ID** can be found in the API Keys section of your Postbase dashboard.

---

## Database

Query your PostgreSQL tables with a fluent, chainable API. Query builders are immutable — every method returns a new builder — and lazy: nothing is sent until you `await` the builder directly (an implicit execute) or call `.single()` / `.maybeSingle()`.

### Select

```dart
// Fetch all posts (wildcard or omit argument — both work)
final result = await postbase.from('posts').select('*');
final result2 = await postbase.from('posts').select();

// Select specific columns
final result3 = await postbase.from('posts').select('id, title, created_at');

// With filters
final result4 = await postbase
    .from('posts')
    .select('*')
    .eq('status', 'published')
    .order('created_at', ascending: false)
    .limit(10);

// Get total count
final result5 = await postbase.from('posts').select('*', const SelectOptions(count: 'exact'));
print(result5.count);
```

### Filter methods

Available on `select()`, `update()`, and `delete()` chains.

| Method | SQL equivalent |
|---|---|
| `.eq(col, val)` | `col = val` |
| `.neq(col, val)` | `col != val` |
| `.gt(col, val)` | `col > val` |
| `.gte(col, val)` | `col >= val` |
| `.lt(col, val)` | `col < val` |
| `.lte(col, val)` | `col <= val` |
| `.like(col, pattern)` | `col LIKE pattern` |
| `.ilike(col, pattern)` | `col ILIKE pattern` |
| `.in_(col, values)` | `col IN (values)` |
| `.is_(col, null \| bool)` | `col IS NULL / TRUE / FALSE` |
| `.contains(col, val)` | `col @> val` |
| `.overlaps(col, val)` | `col && val` |
| `.textSearch(col, query)` | full-text search |
| `.or(filters)` | `col = val OR col = val` |
| `.not(col, op, val)` | `NOT col op val` |

> `in_` and `is_` have a trailing underscore — Dart doesn't reserve `in` or `is` as identifiers the way Python does, but they *are* operator keywords that can't be used as method names, so the convention carries over from the other SDKs for consistency. `or` and `not` need no suffix — Dart has no such keyword clash for either.

### `.or()` — Supabase-compatible filter string

Pass a Supabase-style filter string and the SDK parses it into structured filters before sending to the server. Commas separate OR conditions; values with commas are safe inside parentheses (used by `in`).

```dart
// Simple OR: match either condition
final result = await postbase.from('users').select().or('email.ilike.%alice%,name.ilike.%alice%');

// OR with in operator — values in parens are safe
final result2 = await postbase.from('orders').select().or('status.eq.active,status.in.(pending,review)');

// Combine OR with AND filters — the .eq() is ANDed with the OR group
final result3 = await postbase
    .from('posts')
    .select()
    .eq('published', true)
    .or('title.ilike.%hello%,body.ilike.%hello%');
```

**Supported operators inside `.or()`:** `eq` `neq` `gt` `gte` `lt` `lte` `like` `ilike` `in` `is`

### Joins

Use `.join()` to combine data from related tables. Builders are immutable and can be stacked.

```dart
// Left join — include orders even if no matching user
final result = await postbase
    .from('orders')
    .join('users', on: 'orders.user_id = users.id', type: JoinType.left)
    .select('orders.id, orders.total, users.email');

// Multiple joins
final result2 = await postbase
    .from('orders')
    .join('users', on: 'orders.user_id = users.id', type: JoinType.left)
    .join('products', on: 'orders.product_id = products.id')
    .select('orders.id, users.email, products.name')
    .eq('orders.status', 'active')
    .order('orders.created_at', ascending: false)
    .limit(20);
```

**Join types** (`type` defaults to `JoinType.inner` if omitted): `inner`, `left`, `right`, `full`.

**`on` expression rules** — the server validates the `on` string against a strict allow-list:

- `table.column = table.column`
- Comparison operators: `=`, `<`, `>`, `!=`, `<=`, `>=`
- Identifiers and dotted column references only — no raw SQL, no functions, no subqueries

```dart
// Valid
postbase.from('orders').join('users', on: 'orders.user_id = users.id');

// Invalid — rejected by the server
postbase.from('orders').join('users', on: 'orders.user_id = users.id AND users.active = true');
```

**Column aliases** — when two joined tables share a column name (e.g. both have `id`), use `AS` to rename them. The SDK strips the alias before sending to the server and renames the keys in the returned rows client-side.

```dart
final result = await postbase
    .from('apis')
    .join('pricing_plans', on: 'apis.pricing_plan_id = pricing_plans.id', type: JoinType.left)
    .select('apis.id as api_id, apis.name, pricing_plans.id as plan_id, pricing_plans.name as plan_name');
// result.data![0] == {'api_id': '...', 'name': '...', 'plan_id': '...', 'plan_name': '...'}
```

> **Limitation:** if you select two columns with the same base name without aliasing both (e.g. `apis.id, pricing_plans.id`), the server collapses them to one `id` key before the SDK sees the response — only one value survives. Always alias at least all but one of any colliding columns.

---

### Raw SQL

For queries that can't be expressed with the builder (CTEs, window functions, complex aggregates), use `postbase.sql()`. RLS context is still enforced — the authenticated user's JWT is forwarded exactly as with `.from()`.

```dart
final result = await postbase.sql(
  '''
  SELECT o.id, u.email
  FROM orders o
  INNER JOIN users u ON o.user_id = u.id
  WHERE o.status = \$1
  ''',
  ['active'],
);

// Multiple params
final result2 = await postbase.sql(
  '''
  SELECT p.title, COUNT(c.id) AS count
  FROM posts p
  LEFT JOIN comments c ON c.post_id = p.id
  WHERE p.author_id = \$1 AND p.status = \$2
  GROUP BY p.id, p.title
  ORDER BY count DESC
  LIMIT \$3
  ''',
  [userId, 'published', 10],
);
```

Params replace `$1`, `$2`, `$3`, … placeholders (standard PostgreSQL positional parameters). Never interpolate values directly into the query string — always use params to prevent SQL injection.

---

### Insert

```dart
final result = await postbase.from('posts').insert({'title': 'Hello World', 'status': 'draft'}).select().single();
```

### Update

```dart
final result = await postbase
    .from('posts')
    .update({'status': 'published'})
    .eq('id', postId)
    .select()
    .single();
```

### Upsert

```dart
final result = await postbase
    .from('profiles')
    .upsert({'id': userId, 'username': 'alice'}, onConflict: 'id')
    .select();
```

### Delete

```dart
final result = await postbase.from('posts').delete().eq('id', postId);
```

### Single row helpers

```dart
// Errors if not exactly one row
final result = await postbase.from('posts').select('*').eq('id', postId).single();

// Returns null if not found (no error)
final result2 = await postbase.from('posts').select('*').eq('id', postId).maybeSingle();
```

### Pagination

```dart
// Limit + offset
final result = await postbase.from('posts').select('*').limit(20).offset(40);

// Range (inclusive)
final result2 = await postbase.from('posts').select('*').range(0, 19);
```

---

## Authentication

### Sign up

```dart
final response = await postbase.auth.signUp(email: 'user@example.com', password: 'supersecret', rememberMe: true);
// response.user, response.session, response.error
```

### Sign in with password

```dart
final response = await postbase.auth.signInWithPassword(
  email: 'user@example.com',
  password: 'supersecret',
  rememberMe: true,
);
```

### OTP & Magic Link (passwordless)

**Magic link:**

```dart
await postbase.auth.signInWithOtp(
  email: 'user@example.com',
  type: 'magic_link',
  redirectTo: 'https://yourapp.com/dashboard',
);
```

**6-digit OTP code:**

```dart
// 1. Request the code
await postbase.auth.signInWithOtp(email: 'user@example.com', type: 'otp');

// 2. Verify the code
final response = await postbase.auth.verifyOtp(email: 'user@example.com', token: '123456', rememberMe: true);
// response.user, response.session
```

### Email OTP (the `/email-otp` flow)

```dart
await postbase.auth.signInWithEmailOtp('user@example.com');
final response = await postbase.auth.verifyEmailOtp(email: 'user@example.com', code: '123456', rememberMe: true);
```

### OAuth (browser redirect, PKCE)

Flutter has no single "browser" the SDK can redirect for you — build the authorize URL, open it yourself (typically with [`url_launcher`](https://pub.dev/packages/url_launcher)), and listen for the deep-link/app-link callback (e.g. with [`app_links`](https://pub.dev/packages/app_links)):

```dart
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';

// 1. Build the authorize URL and open it
final oauth = postbase.auth.signInWithOAuth(
  provider: 'google',
  redirectTo: 'com.yourapp://auth-callback',
);
await launchUrl(Uri.parse(oauth.url), mode: LaunchMode.externalApplication);

// 2. Listen for the deep link your app registered (com.yourapp://auth-callback?...)
final appLinks = AppLinks();
appLinks.uriLinkStream.listen((uri) async {
  final response = await postbase.auth.handleOAuthCallback(uri.toString());
  // response.session, response.user, response.error
});
```

Register `com.yourapp://auth-callback` (or your chosen scheme) as a deep link / universal link / app link in your Postbase project's redirect URLs and in your app's `Info.plist` / `AndroidManifest.xml`.

### Sign in with Apple / Google (native id_token — no browser)

For platforms with a native sign-in SDK (`sign_in_with_apple`, `google_sign_in`) that hand you an `idToken` directly, skip the browser redirect entirely:

```dart
final response = await postbase.auth.signInWithIdToken(
  provider: NativeOAuthProvider.apple,
  idToken: appleIdentityToken,
  nonce: nonce, // optional — include if you passed a nonce to the native request
  rememberMe: true,
);

final response2 = await postbase.auth.signInWithIdToken(
  provider: NativeOAuthProvider.google,
  idToken: googleIdToken,
  rememberMe: true,
);
```

> **Note:** the provider must be enabled in your Postbase dashboard. The `clientId` field should contain your Apple Service ID (for web) or comma-separated Bundle IDs (for native), matching the `aud` claim in Apple's `id_token`.

### Remember me

`rememberMe: true` issues a 30-day refresh token instead of the default 7-day one. The flag is stored on the session row server-side, so it's carried forward automatically on every subsequent `refreshSession()` call — no need to keep resending it.

Supported directly (single call, no follow-up needed) on `signUp`, `signInWithPassword`, `verifyOtp`, `verifyEmailOtp`, and `signInWithIdToken`.

**Redirect-based OAuth is the one exception** — the tokens come back as URL query params on the callback, not from a call you control, so there's no request body to put `rememberMe` in. Use `setRememberMe` afterwards instead:

```dart
final response = await postbase.auth.setRememberMe(true);
// response.session!.refreshToken is now valid for 30 days
```

### Get current user / session

```dart
final user = await postbase.auth.getUser();
final session = await postbase.auth.getSession();
```

> `session.expiresAt` is the **access token's** expiry (short-lived, ~1 hour). `session.refreshTokenExpiresAt` is the **refresh token's** expiry (7 or 30 days depending on `rememberMe`). Don't use `expiresAt` to reason about how long the user stays logged in.

### Sign out

```dart
await postbase.auth.signOut();
```

### Update user

```dart
await postbase.auth.updateUser(name: 'Alice', data: {'plan': 'pro'});
```

### Listen to auth state changes

`onAuthStateChange` is a broadcast `Stream` (idiomatic Dart — no callback-list management needed):

```dart
final subscription = postbase.auth.onAuthStateChange.listen((change) {
  // change.event: AuthChangeEvent.signedIn | signedOut | tokenRefreshed | userUpdated
  // change.session
});

// later
await subscription.cancel();
```

### Session persistence

By default (`persistSession: true`, the default in `PostbaseClientOptions`), sessions survive app restarts:

- The **refresh token** (the long-lived credential) is stored in the platform keychain/keystore via [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage).
- The rest of the session (access token, expiry, user) is stored in [`shared_preferences`](https://pub.dev/packages/shared_preferences).

Call `postbase.auth.restoreSession()` once at app startup (e.g. in your root widget's `initState`) to reload a previously persisted session:

```dart
final session = await postbase.auth.restoreSession();
if (session != null) {
  // already signed in
}
```

For short-lived clients (a CLI tool, a service using the service-role key) pass `persistSession: false` to skip storage entirely.

### Admin (service role key required)

```dart
final admin = createClient(url, 'pb_service_your_service_key', options: const PostbaseClientOptions(projectId: 'your-project-id'));

// List users
final result = await admin.auth.admin.listUsers(page: 1, perPage: 50);

// Create user
final result2 = await admin.auth.admin.createUser(
  email: 'new@example.com',
  password: 'password',
  emailConfirm: true,
);

// Update / delete user
await admin.auth.admin.updateUserById(userId, email: 'new@example.com');
await admin.auth.admin.deleteUser(userId);
```

---

## Storage

### Upload a file

Pass `contentType` to ensure the correct MIME type is stored with the file. Accepts `Uint8List` (works everywhere, including Flutter web) or a `dart:io File` (native platforms only).

```dart
import 'dart:io';
import 'dart:typed_data';

final file = File('avatar.png');
final result = await postbase.storage.from('avatars').upload('user-123.png', file, contentType: 'image/png');
// result.data!.path, result.data!.fullPath

// Or pass bytes directly (works on Flutter web too)
final bytes = await file.readAsBytes();
final result2 = await postbase.storage.from('avatars').upload('user-123.png', bytes, contentType: 'image/png');

// Upsert (overwrite an existing file)
final result3 = await postbase.storage.from('avatars').upload(
  'user-123.png',
  bytes,
  contentType: 'image/png',
  upsert: true,
);
```

### Get public URL

```dart
final url = postbase.storage.from('avatars').getPublicUrl('user-123.png');
```

### Download a file

```dart
final result = await postbase.storage.from('avatars').download('user-123.png');
// result.data is Uint8List
```

### Create a signed URL (temporary access)

```dart
final result = await postbase.storage.from('private-docs').createSignedUrl('report.pdf', 3600); // 1 hour
```

### List files

```dart
final result = await postbase.storage.from('avatars').list('folder/', limit: 100);
```

### Delete files

```dart
await postbase.storage.from('avatars').remove(['user-123.png', 'user-456.png']);
```

### Move / Copy

```dart
await postbase.storage.from('docs').move('old-name.pdf', 'new-name.pdf');
await postbase.storage.from('docs').copy('template.pdf', 'copy.pdf');
```

### Bucket management

```dart
// Create
await postbase.storage.createBucket(
  'avatars',
  public: true,
  fileSizeLimit: 5 * 1024 * 1024, // 5 MB
  allowedMimeTypes: ['image/png', 'image/jpeg'],
);

// List
final buckets = await postbase.storage.listBuckets();

// Update
await postbase.storage.updateBucket('avatars', public: false);

// Delete
await postbase.storage.deleteBucket('avatars');

// Empty (delete all objects)
await postbase.storage.emptyBucket('avatars');
```

---

## RPC (PostgreSQL functions)

Call a stored procedure or function in your project's schema:

```dart
final result = await postbase.rpc('get_nearby_posts', args: {'lat': 37.7749, 'lng': -122.4194, 'radius': 10});
```

---

## Email

Send a transactional email using your project's configured email provider (e.g. AWS SES).

```dart
final result = await postbase.email.send(
  to: 'user@example.com',
  subject: 'Welcome!',
  text: 'Hello there',
  html: '<p>Hello there</p>',
  replyTo: 'support@example.com', // optional
);
// result.ok
```

---

## Dart backend / server-side session forwarding (CookieAdapter)

When running behind a Dart server framework (`shelf`, `dart_frog`, etc.) rather than in a Flutter app, you can forward the caller's session cookie to Postbase so RLS policies evaluate against the authenticated user instead of just the anon role. Implement a `CookieAdapter` bridging your framework's request/response to Postbase:

```dart
import 'package:postbase/postbase.dart';

class ShelfCookieAdapter implements CookieAdapter {
  ShelfCookieAdapter(this.request, this.responseHeaders);

  final shelf.Request request;
  final Map<String, String> responseHeaders;

  @override
  List<Cookie> getAll() {
    final header = request.headers['cookie'];
    if (header == null) return [];
    return header.split(';').map((pair) {
      final parts = pair.trim().split('=');
      return Cookie(name: parts[0], value: parts.sublist(1).join('='));
    }).toList();
  }

  @override
  void setAll(List<CookieToSet> cookies) {
    for (final c in cookies) {
      responseHeaders['set-cookie'] = '${c.name}=${c.value}; HttpOnly; Path=/';
    }
  }
}

final postbase = createClient(
  url,
  anonKey,
  options: PostbaseClientOptions(
    projectId: projectId,
    cookies: ShelfCookieAdapter(request, responseHeaders),
  ),
);

final result = await postbase.from('posts').select(); // RLS applies to the signed-in user
```

`getAll`/`setAll` may return sync values or `Future`s — the SDK awaits them automatically if they return a `Future`.

The session cookie is named `postbase-session`. After completing an OAuth flow or otherwise obtaining a session outside the normal sign-in calls, persist it with `auth.setSession(session)` — this writes the `postbase-session` httpOnly cookie via your `CookieAdapter.setAll`, so subsequent requests using the same adapter are authenticated automatically.

```dart
final error = await postbase.auth.setSession(session);
```

This is a Dart-backend-only concern — Flutter apps have no server-rendered request/response cycle, so `cookies` is simply omitted there and session persistence uses device storage instead (see [Session persistence](#session-persistence)).

---

## Row Level Security (RLS)

When a user is signed in (via a forwarded `X-Postbase-Token`/session cookie), their session JWT is automatically forwarded with every query. Your RLS policies can reference the user via:

```sql
current_setting('postbase.user_id', true)  -- the authenticated user's ID
current_setting('postbase.role', true)     -- the user's role
```

Example policy — users can only read their own rows:

```sql
CREATE POLICY "own rows" ON posts
  FOR SELECT USING (
    user_id = current_setting('postbase.user_id', true)::uuid
  );
```

---

## Environment Variables

We recommend storing your Postbase credentials in your platform's env/secrets mechanism rather than hardcoding them (e.g. `--dart-define`, a `.env` file loaded via `flutter_dotenv`, or your CI's secret store):

```
POSTBASE_URL=https://your-postbase-instance.com
POSTBASE_ANON_KEY=pb_anon_...
POSTBASE_PROJECT_ID=your-project-id
# Service key — server-side only, bypasses RLS. Never ship this in a client app.
POSTBASE_SERVICE_KEY=pb_service_...
```

Use your **service role key** (`pb_service_...`) only in trusted server-side Dart code (a `shelf`/`dart_frog` backend, a Cloud Function) — it bypasses RLS and must never ship inside a Flutter app binary.

---

## Type hints

Query results are `QueryResult<T>` / `SingleResult<T>` — plain data-holder classes with `data`, `count` (query results only), and `error` fields. Rows come back as `Map<String, Object?>` by default; pass a `map` function to `from()` to decode them into your own model:

```dart
class Post {
  Post({required this.id, required this.title, required this.status, required this.createdAt});

  final String id;
  final String title;
  final String status;
  final String createdAt;

  factory Post.fromJson(Map<String, Object?> json) => Post(
        id: json['id'] as String,
        title: json['title'] as String,
        status: json['status'] as String,
        createdAt: json['created_at'] as String,
      );
}

final result = await postbase.from<Post>('posts', map: Post.fromJson).select().eq('status', 'published');
// result.data is List<Post>?
```

---

## Realtime (WebSocket subscriptions)

Not implemented in v1 of this SDK. It's on the roadmap as a stretch goal — flag an issue on GitHub if you need it sooner.

---

## License

MIT — see [LICENSE](LICENSE).

---

Built with love by the [Postbase](https://www.getpostbase.com) team.
