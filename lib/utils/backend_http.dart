import 'backend_auth_service.dart';
import 'backend_config.dart';
import 'backend_transport.dart';

class BackendHttp {
  static Future<Map<String, dynamic>> request({
    required String path,
    String method = 'GET',
    Map<String, dynamic>? body,
    bool auth = true,
    Duration? cacheTtl,
    bool forceRefresh = false,
  }) async {
    String? token;
    if (auth) {
      token = await BackendAuthService().getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Not signed in');
      }
    }

    final uri = Uri.parse('${BackendConfig.baseUrl}$path');
    return BackendTransport.request(
      uri: uri,
      method: method,
      body: body,
      token: token,
      cacheTtl: cacheTtl,
      forceRefresh: forceRefresh,
    );
  }
}

