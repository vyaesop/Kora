import 'package:flutter/foundation.dart';

import 'backend_auth_service.dart';
import 'backend_config.dart';
import 'dart:convert';
import 'dart:io';

class ErrorTelemetry {
  static Future<void> _send(Map<String, dynamic> payload) async {
    try {
      final token = await BackendAuthService().getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[telemetry] $payload');
        return;
      }

      final uri = Uri.parse('${BackendConfig.baseUrl}/api/telemetry/client');
      final client = HttpClient();
      try {
        final req = await client.openUrl('POST', uri);
        req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        req.add(utf8.encode(jsonEncode(payload)));
        await req.close();
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      // swallow telemetry failures
    }
  }

  static Future<void> logEvent({
    required String feature,
    required String name,
    Map<String, dynamic>? metadata,
  }) async {
    await _send({
      'type': 'event',
      'feature': feature,
      'name': name,
      'metadata': metadata ?? {},
      'platform': defaultTargetPlatform.name,
    });
  }

  static Future<void> log({
    required String feature,
    required String operation,
    required Object error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) async {
    await _send({
      'type': 'error',
      'feature': feature,
      'operation': operation,
      'error': error.toString(),
      'stack': stackTrace?.toString(),
      'metadata': metadata ?? {},
      'platform': defaultTargetPlatform.name,
    });
  }
}