/// postbase — the official Dart/Flutter client for Postbase.
///
/// Postbase is a self-hosted, open-source backend-as-a-service built on
/// PostgreSQL: a REST query API, authentication, file storage, and
/// row-level security.
///
/// ```dart
/// import 'package:postbase/postbase.dart';
///
/// final postbase = createClient(
///   'https://your-postbase-instance.com',
///   'pb_anon_your_api_key',
///   options: const PostbaseClientOptions(projectId: 'your-project-id'),
/// );
///
/// final result = await postbase.from('posts').select().eq('status', 'published');
/// ```
library;

export 'src/auth/auth_admin_client.dart'
    show AuthAdminClient, AuthAdminUserResult, AuthAdminUsersResult;
export 'src/auth/auth_client.dart' show AuthClient, AuthStateChange;
export 'src/auth/oauth.dart' show OAuthCallbackResult, PostbaseOAuthUrl;
export 'src/client.dart'
    show PostbaseClient, PostbaseClientOptions, createClient;
export 'src/email/email_client.dart' show EmailClient, EmailSendResult;
export 'src/query/delete_builder.dart' show DeleteBuilder;
export 'src/query/insert_builder.dart' show InsertBuilder;
export 'src/query/query_builder.dart' show QueryBuilder, SelectOptions;
export 'src/query/update_builder.dart' show UpdateBuilder;
export 'src/storage/storage_client.dart'
    show SortBy, StorageBucketClient, StorageClient, UploadResult;
export 'src/types.dart';
