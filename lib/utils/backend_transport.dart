import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BackendTransport {
  BackendTransport._();

  static const String _prefsIndexKey = 'backend_transport_cache_index';
  static const String _prefsPrefix = 'backend_transport_cache_';
  static const int _maxPersistedEntries = 80;
  static const Duration _defaultGetCacheTtl = Duration(minutes: 3);
  static const Duration _offlineFallbackMaxAge = Duration(days: 7);

  static final http.Client _client = http.Client();

  static final Map<String, _CacheEntry> _getCache = <String, _CacheEntry>{};
  static final Map<String, Future<Map<String, dynamic>>> _pendingGets =
      <String, Future<Map<String, dynamic>>>{};
  static SharedPreferences? _prefs;

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
    final Duration effectiveCacheTtl = isGet
        ? (cacheTtl ?? _defaultGetCacheTtl)
        : _defaultGetCacheTtl;
    final cacheKey = _cacheKey(
      method: normalizedMethod,
      uri: uri,
      token: token,
    );
    _PersistedCacheRecord? staleFallback;

    if (isGet && !forceRefresh) {
      final cached = _getCache[cacheKey];
      if (cached != null && !cached.isExpired) {
        return Map<String, dynamic>.from(cached.data);
      }

      final persisted = await _readPersistedRecord(cacheKey);
      if (persisted != null) {
        final entry = _CacheEntry(
          data: Map<String, dynamic>.from(persisted.data),
          expiresAt: persisted.fetchedAt.add(effectiveCacheTtl),
          fetchedAt: persisted.fetchedAt,
        );
        _getCache[cacheKey] = entry;
        if (!entry.isExpired) {
          return Map<String, dynamic>.from(entry.data);
        }
        if (persisted.age <= _offlineFallbackMaxAge) {
          staleFallback = persisted;
        }
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
      if (isGet) {
        final entry = _CacheEntry(
          data: Map<String, dynamic>.from(data),
          expiresAt: DateTime.now().add(effectiveCacheTtl),
          fetchedAt: DateTime.now(),
        );
        _getCache[cacheKey] = entry;
        await _persistRecord(
          cacheKey,
          _PersistedCacheRecord(
            data: Map<String, dynamic>.from(data),
            fetchedAt: entry.fetchedAt,
          ),
        );
      } else if (!isGet) {
        clearGetCache();
      }
      return data;
    } on Object {
      if (isGet && staleFallback != null) {
        return _decorateStaleResponse(staleFallback);
      }
      rethrow;
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
    final req = http.Request(method, uri);
    req.headers['accept'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      req.headers['authorization'] = 'Bearer $token';
    }
    if (body != null) {
      req.headers['content-type'] = 'application/json';
      req.body = jsonEncode(body);
    }

    final streamed = await _client.send(req);
    final res = await http.Response.fromStream(streamed);
    final raw = res.body;
    final contentTypeHeader = res.headers['content-type']?.toLowerCase();
    final trimmed = raw.trimLeft();
    final looksLikeHtml =
        trimmed.startsWith('<!DOCTYPE html') || trimmed.startsWith('<html');

    if (raw.isNotEmpty &&
        (looksLikeHtml ||
            (contentTypeHeader != null &&
                !contentTypeHeader.contains('json') &&
                !contentTypeHeader.contains('text/plain')))) {
      throw BackendRequestException(
        message:
            'This feature is not available from the current backend response yet.',
        statusCode: res.statusCode,
        payload: <String, dynamic>{
          'ok': false,
          'code': 'ENDPOINT_UNAVAILABLE',
          'contentType': contentTypeHeader,
          'preview': trimmed.substring(0, math.min(trimmed.length, 120)),
        },
      );
    }

    final decoded = raw.isEmpty ? const <String, dynamic>{} : jsonDecode(raw);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'data': decoded};

    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] == false) {
      throw BackendRequestException(
        message: (data['error'] ?? 'Request failed').toString(),
        statusCode: res.statusCode,
        payload: data,
      );
    }

    return data;
  }

  static Map<String, dynamic> _decorateStaleResponse(
    _PersistedCacheRecord record,
  ) {
    return <String, dynamic>{
      ...record.data,
      '_cache': <String, dynamic>{
        'stale': true,
        'fetchedAt': record.fetchedAt.toIso8601String(),
      },
    };
  }

  static String _cacheKey({
    required String method,
    required Uri uri,
    required String? token,
  }) {
    return '$method|${token ?? ''}|${uri.toString()}';
  }

  static Future<SharedPreferences> _prefsInstance() async {
    final cached = _prefs;
    if (cached != null) {
      return cached;
    }
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    return prefs;
  }

  static String _persistedEntryKey(String cacheKey) {
    final encoded = base64Url.encode(utf8.encode(cacheKey));
    return '$_prefsPrefix$encoded';
  }

  static Future<_PersistedCacheRecord?> _readPersistedRecord(
    String cacheKey,
  ) async {
    final prefs = await _prefsInstance();
    final raw = prefs.getString(_persistedEntryKey(cacheKey));
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final fetchedAt = DateTime.tryParse(
        (decoded['fetchedAt'] ?? '').toString(),
      );
      final data = decoded['data'];
      if (fetchedAt == null || data is! Map<String, dynamic>) {
        return null;
      }
      return _PersistedCacheRecord(
        data: Map<String, dynamic>.from(data),
        fetchedAt: fetchedAt,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _persistRecord(
    String cacheKey,
    _PersistedCacheRecord record,
  ) async {
    final prefs = await _prefsInstance();
    final entryKey = _persistedEntryKey(cacheKey);
    await prefs.setString(
      entryKey,
      jsonEncode(<String, dynamic>{
        'fetchedAt': record.fetchedAt.toIso8601String(),
        'data': record.data,
      }),
    );

    final currentIndex = prefs.getStringList(_prefsIndexKey) ?? <String>[];
    final nextIndex = <String>[
      entryKey,
      ...currentIndex.where((item) => item != entryKey),
    ];
    if (nextIndex.length > _maxPersistedEntries) {
      final toRemove = nextIndex.sublist(_maxPersistedEntries);
      for (final key in toRemove) {
        await prefs.remove(key);
      }
      nextIndex.removeRange(_maxPersistedEntries, nextIndex.length);
    }
    await prefs.setStringList(_prefsIndexKey, nextIndex);
  }
}

class _CacheEntry {
  final Map<String, dynamic> data;
  final DateTime expiresAt;
  final DateTime fetchedAt;

  const _CacheEntry({
    required this.data,
    required this.expiresAt,
    required this.fetchedAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class _PersistedCacheRecord {
  final Map<String, dynamic> data;
  final DateTime fetchedAt;

  const _PersistedCacheRecord({
    required this.data,
    required this.fetchedAt,
  });

  Duration get age => DateTime.now().difference(fetchedAt);
}

class BackendRequestException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? payload;

  const BackendRequestException({
    required this.message,
    this.statusCode,
    this.payload,
  });

  @override
  String toString() => 'Exception: $message';
}
