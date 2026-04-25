import 'package:flutter/foundation.dart';

import 'backend_http.dart';

class ErrorTelemetry {
  static Future<void> _send(Map<String, dynamic> payload) async {
    try {
      await BackendHttp.request(
        path: '/api/telemetry/client',
        method: 'POST',
        body: payload,
      );
    } catch (_) {
      debugPrint('[telemetry] $payload');
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
