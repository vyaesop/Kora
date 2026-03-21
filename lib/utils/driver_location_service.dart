import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

import 'backend_auth_service.dart';
import 'backend_config.dart';

class DriverLocationService {
  final String driverId;
  StreamSubscription<Position>? _positionStream;
  final BackendAuthService _authService = BackendAuthService();

  DriverLocationService(this.driverId);

  void start() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine) {
      debugPrint('Location permission denied.');
      return;
    }
    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permission denied forever.');
      return;
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) async {
      try {
        final token = await _authService.getToken();
        if (token == null || token.isEmpty) {
          debugPrint('Driver location upload skipped: no auth token');
          return;
        }

        final uri = Uri.parse('${BackendConfig.baseUrl}/api/drivers/$driverId/location');
        final client = HttpClient();
        try {
          final req = await client.openUrl('PUT', uri);
          req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
          req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
          req.add(
            utf8.encode(
              jsonEncode({
                'latitude': position.latitude,
                'longitude': position.longitude,
              }),
            ),
          );
          final res = await req.close();
          if (res.statusCode < 200 || res.statusCode >= 300) {
            debugPrint('Driver location upload failed with status ${res.statusCode}');
          }
        } finally {
          client.close(force: true);
        }
      } catch (error) {
        debugPrint('Driver location upload error: $error');
      }
    }, onError: (Object error) {
      debugPrint('Driver location stream error: $error');
    });
  }

  void stop() {
    _positionStream?.cancel();
    _positionStream = null;
  }
}
