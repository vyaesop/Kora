import 'package:flutter/foundation.dart';

class BackendConfig {
  static const String _hostedFallbackUrl =
      'https://kora-backend-alpha.vercel.app';
  static const bool _useLocalDebugBackend = bool.fromEnvironment(
    'KORA_USE_LOCAL_BACKEND',
    defaultValue: false,
  );

  static String get baseUrl {
    final configured = _normalize(const String.fromEnvironment('KORA_API_BASE_URL'));
    if (configured != null) {
      return configured;
    }

    if (kReleaseMode) {
      throw StateError(
        'Missing KORA_API_BASE_URL. Build release artifacts with '
        '--dart-define=KORA_API_BASE_URL=https://kora-backend-alpha.vercel.app',
      );
    }

    if (kIsWeb) {
      return 'http://localhost:3000';
    }

    if (!_useLocalDebugBackend) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
        case TargetPlatform.iOS:
          return _hostedFallbackUrl;
        case TargetPlatform.macOS:
        case TargetPlatform.windows:
        case TargetPlatform.linux:
        case TargetPlatform.fuchsia:
          break;
      }
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3000';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'http://localhost:3000';
    }
  }

  static String? _normalize(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }
}
