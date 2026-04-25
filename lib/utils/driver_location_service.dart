import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'backend_http.dart';
import 'ethiopia_locations.dart';
import 'session_preferences.dart';

class DriverLocationService {
  final String driverId;
  StreamSubscription<Position>? _positionStream;
  String? _lastCity;

  DriverLocationService(this.driverId);

  static Future<bool> ensureCriticalLocationAccess(BuildContext context) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!context.mounted) return false;
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Location required'),
          content: const Text(
            'Drivers need precise location access so Kora can show nearby loads, live tracking, and route-based suggestions. Please turn location services on to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
      if (openSettings == true) {
        await Geolocator.openLocationSettings();
      }
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      if (!context.mounted) return false;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Allow precise location'),
          content: const Text(
            'Location is essential for drivers on Kora. We use it for nearby load discovery, return-load suggestions, and shipment tracking for cargo owners.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      if (!context.mounted) return false;
      final openAppSettings = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Location blocked'),
          content: const Text(
            'Location permission was permanently denied. Please open app settings and allow precise location for Kora to work properly for drivers.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Open app settings'),
            ),
          ],
        ),
      );
      if (openAppSettings == true) {
        await Geolocator.openAppSettings();
      }
      return false;
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  static Future<String?> getCurrentDriverCity({
    Duration timeLimit = const Duration(seconds: 6),
  }) async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return await SessionPreferences.getDriverCity();
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(timeLimit);

      final match = findNearestEthiopiaCity(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      final city = match?.city.city;
      if (city != null && city.isNotEmpty) {
        await SessionPreferences.saveDriverCity(city);
      }
      return city ?? await SessionPreferences.getDriverCity();
    } catch (_) {
      return await SessionPreferences.getDriverCity();
    }
  }

  Future<void> start() async {
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      debugPrint('Driver location stream not started: permission missing.');
      return;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      debugPrint(
        'Driver location stream not started: location services disabled.',
      );
      return;
    }

    await _positionStream?.cancel();
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 50,
          ),
        ).listen(
          (Position position) async {
            try {
              final match = findNearestEthiopiaCity(
                latitude: position.latitude,
                longitude: position.longitude,
              );
              final cityName = match?.city.city;
              if (cityName != null &&
                  cityName.isNotEmpty &&
                  cityName != _lastCity) {
                _lastCity = cityName;
                await SessionPreferences.saveDriverCity(cityName);
              }

              await BackendHttp.request(
                path: '/api/drivers/$driverId/location',
                method: 'PUT',
                body: {
                  'latitude': position.latitude,
                  'longitude': position.longitude,
                },
              );
            } catch (error) {
              debugPrint('Driver location upload error: $error');
            }
          },
          onError: (Object error) {
            debugPrint('Driver location stream error: $error');
          },
        );
  }

  void stop() {
    _positionStream?.cancel();
    _positionStream = null;
  }
}
