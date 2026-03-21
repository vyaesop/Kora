import 'package:shared_preferences/shared_preferences.dart';

class ExperimentService {
  static String _variantKey(String experiment) => 'exp_variant_$experiment';
  static String _exposedKey(String experiment) => 'exp_exposed_$experiment';

  static Future<String> getOrAssignVariant({
    required String experiment,
    required String userSeed,
    List<String> variants = const ['control', 'treatment'],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_variantKey(experiment));
    if (existing != null && variants.contains(existing)) return existing;

    final hash = userSeed.codeUnits.fold<int>(0, (acc, v) => (acc * 31 + v) & 0x7fffffff);
    final variant = variants[hash % variants.length];
    await prefs.setString(_variantKey(experiment), variant);
    return variant;
  }

  static Future<bool> markExposedOnce(String experiment) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _exposedKey(experiment);
    final seen = prefs.getBool(key) == true;
    if (!seen) {
      await prefs.setBool(key, true);
    }
    return !seen;
  }
}

