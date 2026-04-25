import 'package:shared_preferences/shared_preferences.dart';
import 'package:kora/model/thread_message.dart';

class RecommendationService {
  static const _routeKey = 'recent_route_tokens';

  static Future<List<String>> loadRecentRouteTokens() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_routeKey) ?? <String>[];
  }

  static Future<void> rememberRoute(String start, String end) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_routeKey) ?? <String>[];
    final tokens = <String>{
      ...existing,
      _firstToken(start),
      _firstToken(end),
    }..removeWhere((t) => t.isEmpty);

    final trimmed = tokens.take(8).toList();
    await prefs.setStringList(_routeKey, trimmed);
  }

  static double scoreLoad({
    required ThreadMessage thread,
    required bool routeFits,
    required List<String> recentTokens,
    double driverMaxWeightKg = 0,
  }) {
    double score = 0;

    if (routeFits) score += 40;

    final startToken = _firstToken(thread.start).toLowerCase();
    final endToken = _firstToken(thread.end).toLowerCase();
    if (recentTokens.map((e) => e.toLowerCase()).contains(startToken)) score += 25;
    if (recentTokens.map((e) => e.toLowerCase()).contains(endToken)) score += 25;

    if (driverMaxWeightKg > 0) {
      final ratio = thread.weight / driverMaxWeightKg;
      if (ratio <= 0.6) {
        score += 10;
      } else if (ratio <= 1.0) {
        score += 5;
      } else {
        score -= 20;
      }
    }

    return score;
  }

  static double scoreReturnLoad({
    required ThreadMessage thread,
    required String returnOrigin,
    required String originalStart,
    required List<String> recentTokens,
  }) {
    double score = 0;

    final startToken = _firstToken(thread.start).toLowerCase();
    final endToken = _firstToken(thread.end).toLowerCase();
    final originToken = _firstToken(returnOrigin).toLowerCase();
    final originalStartToken = _firstToken(originalStart).toLowerCase();
    final loweredRecent = recentTokens.map((e) => e.toLowerCase()).toSet();

    if (startToken == originToken && originToken.isNotEmpty) {
      score += 60;
    }
    if (endToken == originalStartToken && originalStartToken.isNotEmpty) {
      score += 15;
    }
    if (loweredRecent.contains(endToken)) {
      score += 18;
    }
    if (loweredRecent.contains(startToken)) {
      score += 8;
    }
    if (thread.weight > 0 && thread.weight <= 12000) {
      score += 6;
    }

    return score;
  }

  static String _firstToken(String value) {
    final parts = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return parts.isEmpty ? '' : parts.first;
  }
}

