import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/user.dart';
import 'backend_config.dart';
import 'backend_transport.dart';

class BackendAuthService {
  static const _tokenKey = 'kora_auth_token';
  static const _userKey = 'kora_auth_user';
  static String? _cachedToken;
  static Map<String, dynamic>? _cachedUserMap;
  static bool _cacheLoaded = false;

  Future<Map<String, dynamic>> _request({
    required String path,
    String method = 'GET',
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final uri = Uri.parse('${BackendConfig.baseUrl}$path');
    return BackendTransport.request(
      uri: uri,
      method: method,
      body: body,
      token: token,
    );
  }

  UserModel _toUserModel(Map<String, dynamic> payload) {
    return UserModel(
      id: (payload['id'] ?? '').toString(),
      name: (payload['name'] ?? '').toString(),
      username:
          (payload['username'] ??
                  payload['phoneNumber'] ??
                  payload['email'] ??
                  '')
              .toString(),
      followers: const [],
      following: const [],
      profileImageUrl: payload['profileImageUrl']?.toString(),
      bio: payload['bio']?.toString(),
      link: payload['link']?.toString(),
      userType: (payload['userType'] ?? 'Cargo').toString(),
      truckType: payload['truckType']?.toString(),
      address: payload['address']?.toString(),
      licensePlate: payload['licensePlate']?.toString(),
      libre: payload['libre']?.toString(),
      tradeLicensePhoto: payload['tradeLicensePhoto']?.toString(),
      tradeRegistrationCertificatePhoto:
          payload['tradeRegistrationCertificatePhoto']?.toString(),
      tinNumber: payload['tinNumber']?.toString(),
      licenseNumberPhoto: payload['licenseNumberPhoto']?.toString(),
      idPhoto: payload['idPhoto']?.toString(),
      acceptedLoads: const [],
      termsAccepted: true,
      privacyAccepted: true,
      verificationStatus: (payload['verificationStatus'] ?? 'not_submitted')
          .toString(),
    );
  }

  Future<UserModel> login({
    required String phoneNumber,
    required String password,
  }) async {
    final data = await _request(
      path: '/api/auth/login',
      method: 'POST',
      body: {'phoneNumber': phoneNumber, 'password': password},
    );

    final token = (data['token'] ?? '').toString();
    final userMap =
        (data['user'] as Map<String, dynamic>? ?? <String, dynamic>{});
    await _saveSession(token: token, user: userMap);
    return _toUserModel(userMap);
  }

  Future<UserModel> register({
    required String phoneNumber,
    required String password,
    required String name,
    required String userType,
    String? username,
    String? truckType,
    String? address,
  }) async {
    final data = await _request(
      path: '/api/auth/register',
      method: 'POST',
      body: {
        'phoneNumber': phoneNumber,
        'password': password,
        'name': name,
        'userType': userType,
        'username': username,
        'truckType': truckType,
        'address': address,
      },
    );

    final token = (data['token'] ?? '').toString();
    final userMap =
        (data['user'] as Map<String, dynamic>? ?? <String, dynamic>{});
    await _saveSession(token: token, user: userMap);
    return _toUserModel(userMap);
  }

  Future<void> requestPasswordReset({required String phoneNumber}) async {
    await _request(
      path: '/api/auth/forgot-password',
      method: 'POST',
      body: {'phoneNumber': phoneNumber},
    );
  }

  Future<void> resetPassword({
    required String phoneNumber,
    required String code,
    required String newPassword,
  }) async {
    await _request(
      path: '/api/auth/reset-password',
      method: 'POST',
      body: {'phoneNumber': phoneNumber, 'code': code, 'password': newPassword},
    );
  }

  Future<UserModel?> restoreSession() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final data = await _request(path: '/api/auth/me', token: token);
      final userMap =
          (data['user'] as Map<String, dynamic>? ?? <String, dynamic>{});
      await _saveSession(token: token, user: userMap);
      return _toUserModel(userMap);
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  Future<String?> getToken() async {
    await _primeCache();
    return _cachedToken;
  }

  Future<Map<String, dynamic>?> getStoredUserMap() async {
    await _primeCache();
    return _cachedUserMap == null
        ? null
        : Map<String, dynamic>.from(_cachedUserMap!);
  }

  Future<String?> getCurrentUserId() async {
    final user = await getStoredUserMap();
    final id = user?['id'];
    if (id == null) {
      return null;
    }
    final value = id.toString().trim();
    return value.isEmpty ? null : value;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    _cachedToken = null;
    _cachedUserMap = null;
    _cacheLoaded = true;
  }

  Future<void> _saveSession({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
    _cachedToken = token;
    _cachedUserMap = Map<String, dynamic>.from(user);
    _cacheLoaded = true;
  }

  Future<void> _primeCache() async {
    if (_cacheLoaded) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);

    final rawUser = prefs.getString(_userKey);
    if (rawUser != null && rawUser.isNotEmpty) {
      try {
        _cachedUserMap = jsonDecode(rawUser) as Map<String, dynamic>;
      } catch (_) {
        _cachedUserMap = null;
      }
    } else {
      _cachedUserMap = null;
    }

    _cacheLoaded = true;
  }
}
