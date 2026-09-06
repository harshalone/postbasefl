import 'package:postbase/postbase.dart';

Future<void> main() async {
  final postbase = createClient(
    'https://your-postbase-instance.com',
    'pb_anon_your_api_key',
    options: const PostbaseClientOptions(projectId: 'your-project-id'),
  );

  final result = await postbase.from('posts').select().eq('status', 'published').order('created_at', ascending: false).limit(10);

  if (result.error != null) {
    print('Query failed: ${result.error}');
    return;
  }
  print('Posts: ${result.data}');

  postbase.dispose();
}
