import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionPreferences {
  static const String _localeKey = 'app_locale';
  static const String _languageChosenKey = 'app_language_chosen';
  static const String _driverCityKey = 'driver_city_hint';
  static const String _driverCityUpdatedKey = 'driver_city_updated_at';

  static Future<void> saveLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
    await prefs.setBool(_languageChosenKey, true);
  }

  static Future<Locale?> getSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_localeKey);
    if (value == null || value.isEmpty) {
      return null;
    }
    return Locale(value);
  }

  static Future<bool> hasSelectedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_languageChosenKey) ?? false;
  }

  static Future<bool> hasSeenTour(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tourKey(userId)) ?? false;
  }

  static Future<void> markTourSeen(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tourKey(userId), true);
  }

  static Future<void> saveDriverCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_driverCityKey, city);
    await prefs.setString(
      _driverCityUpdatedKey,
      DateTime.now().toIso8601String(),
    );
  }

  static Future<String?> getDriverCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_driverCityKey);
  }

  static Future<DateTime?> getDriverCityUpdatedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_driverCityUpdatedKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static String _tourKey(String userId) => 'tour_seen_$userId';
}
