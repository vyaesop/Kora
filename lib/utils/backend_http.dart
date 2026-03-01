import 'dart:convert';
import 'dart:io';

import 'backend_auth_service.dart';
import 'backend_config.dart';

class BackendHttp {
  static Future<Map<String, dynamic>> request({
    required String path,
    String method = 'GET',
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    String? token;
    if (auth) {
      token = await BackendAuthService().getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Not signed in');
      }
    }

    final uri = Uri.parse('${BackendConfig.baseUrl}$path');
    final client = HttpClient();
    try {
      final req = await client.openUrl(method, uri);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      if (token != null && token.isNotEmpty) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }

      if (body != null) {
        req.add(utf8.encode(jsonEncode(body)));
      }

      final res = await req.close();
      final raw = await utf8.decoder.bind(res).join();
      final data = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw) as Map<String, dynamic>;

      if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] == false) {
        throw Exception((data['error'] ?? 'Request failed').toString());
      }

      return data;
    } finally {
      client.close(force: true);
    }
  }
}
