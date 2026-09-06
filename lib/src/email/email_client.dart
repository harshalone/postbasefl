/// Email client — `/api/email/v1/{projectId}/send`.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

class EmailSendResult {
  const EmailSendResult({required this.ok, required this.error});

  final bool ok;
  final String? error;
}

class EmailClient {
  EmailClient(this._client, String baseUrl, this._apiKey, String projectId,
      Map<String, String>? extraHeaders)
      : _url = '$baseUrl/api/email/v1/$projectId/send',
        _extraHeaders = extraHeaders ?? const {};

  final http.Client _client;
  final String _url;
  final String _apiKey;
  final Map<String, String> _extraHeaders;

  /// Send a transactional email using the project's configured email provider.
  Future<EmailSendResult> send({
    required String to,
    required String subject,
    String? text,
    String? html,
    String? replyTo,
  }) async {
    try {
      final res = await _client.post(
        Uri.parse(_url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
          ..._extraHeaders,
        },
        body: jsonEncode({
          'to': to,
          'subject': subject,
          'text': text,
          'html': html,
          'replyTo': replyTo
        }),
      );
      final json = jsonDecode(res.body) as Map<String, Object?>;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return EmailSendResult(
            ok: false,
            error: json['error'] as String? ?? 'Failed to send email');
      }
      return const EmailSendResult(ok: true, error: null);
    } catch (err) {
      return EmailSendResult(ok: false, error: err.toString());
    }
  }
}
