import 'dart:async';
import 'dart:convert';
import 'dart:io';

class BackendTransport {
  BackendTransport._();

  static final HttpClient _client = () {
    final client = HttpClient()
      ..autoUncompress = true
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 15)
      ..maxConnectionsPerHost = 8;
    return client;
  }();

  static final Map<String, _CacheEntry> _getCache = <String, _CacheEntry>{};
  static final Map<String, Future<Map<String, dynamic>>> _pendingGets =
      <String, Future<Map<String, dynamic>>>{};

  static Future<Map<String, dynamic>> request({
    required Uri uri,
    String method = 'GET',
    Map<String, dynamic>? body,
    String? token,
    Duration? cacheTtl,
    bool forceRefresh = false,
  }) async {
    final normalizedMethod = method.toUpperCase();
    final isGet = normalizedMethod == 'GET';
    final cacheKey = _cacheKey(
      method: normalizedMethod,
      uri: uri,
      token: token,
    );

    if (isGet && !forceRefresh) {
      final cached = _getCache[cacheKey];
      if (cached != null && !cached.isExpired) {
        return Map<String, dynamic>.from(cached.data);
      }

      final pending = _pendingGets[cacheKey];
      if (pending != null) {
        return pending;
      }
    }

    final requestFuture = _send(
      uri: uri,
      method: normalizedMethod,
      body: body,
      token: token,
    );

    if (isGet) {
      _pendingGets[cacheKey] = requestFuture;
    }

    try {
      final data = await requestFuture;
      if (isGet && cacheTtl != null) {
        _getCache[cacheKey] = _CacheEntry(
          data: Map<String, dynamic>.from(data),
          expiresAt: DateTime.now().add(cacheTtl),
        );
      } else if (!isGet) {
        clearGetCache();
      }
      return data;
    } finally {
      if (isGet) {
        _pendingGets.remove(cacheKey);
      }
    }
  }

  static void clearGetCache() {
    _getCache.clear();
  }

  static Future<Map<String, dynamic>> _send({
    required Uri uri,
    required String method,
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final req = await _client.openUrl(method, uri);
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');
    req.headers.set(HttpHeaders.acceptEncodingHeader, 'gzip');
    if (token != null && token.isNotEmpty) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    if (body != null) {
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.add(utf8.encode(jsonEncode(body)));
    }

    final res = await req.close();
    final raw = await utf8.decoder.bind(res).join();
    final decoded = raw.isEmpty ? const <String, dynamic>{} : jsonDecode(raw);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'data': decoded};

    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] == false) {
      throw Exception((data['error'] ?? 'Request failed').toString());
    }

    return data;
  }

  static String _cacheKey({
    required String method,
    required Uri uri,
    required String? token,
  }) {
    return '$method|${token ?? ''}|${uri.toString()}';
  }
}

class _CacheEntry {
  final Map<String, dynamic> data;
  final DateTime expiresAt;

  const _CacheEntry({
    required this.data,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
