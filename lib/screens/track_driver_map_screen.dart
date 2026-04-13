import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:kora/app_localizations.dart';
import 'package:kora/utils/app_theme.dart';
import 'package:kora/utils/backend_http.dart';
import 'package:kora/utils/delivery_status.dart';
import 'package:kora/utils/ethiopia_locations.dart';

class DriverLocationSnapshot {
  final LatLng? location;
  final DateTime? updatedAt;
  const DriverLocationSnapshot({this.location, this.updatedAt});
}

class TrackDriverMapScreen extends StatefulWidget {
  final String driverId;
  final String loadId;
  const TrackDriverMapScreen({
    super.key,
    required this.driverId,
    required this.loadId,
  });

  @override
  State<TrackDriverMapScreen> createState() => _TrackDriverMapScreenState();
}

class _TrackDriverMapScreenState extends State<TrackDriverMapScreen> {
  final MapController _mapController = MapController();
  final Distance _distance = const Distance();
  static const double _mapZoom = 13.0;
  static const double _mapRecenterMeters = 50.0;
  static const Duration _defaultPollInterval = Duration(seconds: 30);
  static const Duration _slowPollInterval = Duration(minutes: 2);

  DriverLocationSnapshot? _driverSnapshot;
  Map<String, dynamic>? _threadData;
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;
  LatLng? _lastMapCenter;
  String? _lastStatus;

  @override
  void initState() {
    super.initState();
    _refresh();
    _scheduleNextRefresh();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  DriverLocationSnapshot _parseLocation(Map<String, dynamic>? map) {
    if (map == null) return const DriverLocationSnapshot();
    final lat = (map['latitude'] as num?)?.toDouble();
    final lng = (map['longitude'] as num?)?.toDouble();
    final updatedAtRaw = map['updatedAt']?.toString();
    final updatedAt = updatedAtRaw == null ? null : DateTime.tryParse(updatedAtRaw);
    if (lat == null || lng == null) return const DriverLocationSnapshot();
    return DriverLocationSnapshot(
      location: LatLng(lat, lng),
      updatedAt: updatedAt,
    );
  }

  Duration _pollIntervalForStatus(String? status) {
    switch (status) {
      case 'accepted':
      case 'driving_to_location':
        return _defaultPollInterval;
      case 'picked_up':
      case 'on_the_road':
        return const Duration(seconds: 45);
      case 'delivered':
      case 'cancelled':
        return _slowPollInterval;
      default:
        return _defaultPollInterval;
    }
  }

  void _scheduleNextRefresh({Duration? interval}) {
    _pollTimer?.cancel();
    final nextInterval = interval ?? _defaultPollInterval;
    _pollTimer = Timer(nextInterval, () {
      if (!mounted) return;
      _refresh(showLoader: false);
    });
  }

  Future<void> _refresh({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final responses = await Future.wait([
        BackendHttp.request(
          path: '/api/drivers/${widget.driverId}/location',
          forceRefresh: true,
        ),
        BackendHttp.request(
          path: '/api/threads/${widget.loadId}',
          forceRefresh: true,
        ),
      ]);
      final locationData = responses[0];
      final threadData = responses[1];
      final snapshot =
          _parseLocation(locationData['location'] as Map<String, dynamic>?);
      final nextStatus =
          (threadData['thread'] as Map<String, dynamic>?)?['deliveryStatus']
              ?.toString();
      final pollInterval = _pollIntervalForStatus(nextStatus);

      if (!mounted) return;
      setState(() {
        _driverSnapshot = snapshot;
        _threadData = threadData['thread'] as Map<String, dynamic>?;
        _loading = false;
        _error = null;
        _lastStatus = nextStatus;
      });
      _scheduleNextRefresh(interval: pollInterval);
      _maybeRecenterMap(snapshot.location);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
      debugPrint('TrackDriverMapScreen refresh error: $e');
      _scheduleNextRefresh(interval: _slowPollInterval);
    }
  }

  void _maybeRecenterMap(LatLng? nextLocation) {
    if (nextLocation == null) return;
    if (_lastMapCenter == null) {
      _lastMapCenter = nextLocation;
      _mapController.move(nextLocation, _mapZoom);
      return;
    }

    final movedMeters = _distance.as(
      LengthUnit.Meter,
      _lastMapCenter!,
      nextLocation,
    );
    if (movedMeters >= _mapRecenterMeters) {
      _lastMapCenter = nextLocation;
      _mapController.move(nextLocation, _mapZoom);
    }
  }

  bool _isStale(DateTime? updatedAt) {
    if (updatedAt == null) return true;
    return DateTime.now().difference(updatedAt).inMinutes >= 5;
  }

  String _updatedLabel(DateTime? updatedAt) {
    if (updatedAt == null) return 'Last update unavailable';
    final diff = DateTime.now().difference(updatedAt);
    if (diff.inSeconds < 60) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
    return 'Updated ${diff.inHours}h ago';
  }

  String _etaLabel(double kmRemaining) {
    if (kmRemaining <= 0) return 'Arrived';
    // Lightweight ETA estimate for UX only.
    const avgKmh = 45.0;
    final minutes = (kmRemaining / avgKmh * 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = (minutes / 60).floor();
    final rem = minutes % 60;
    return '${hours}h ${rem}m';
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(localizations.tr('trackDriver')),
      ),
      body: Builder(
        builder: (context) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('${localizations.tr('liveLocationError')} $_error'),
              ),
            );
          }

          final data = _driverSnapshot;
          final driverLocation = data?.location;
          if (driverLocation == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                    'Waiting for driver location update. Make sure the driver has location enabled.'),
              ),
            );
          }

          final stale = _isStale(data?.updatedAt);
          final endLat = (_threadData?['endLat'] as num?)?.toDouble();
          final endLng = (_threadData?['endLng'] as num?)?.toDouble();
          final hasDestination = endLat != null && endLng != null;
          final destination = hasDestination ? LatLng(endLat, endLng) : null;
          final remainingKm = destination == null
              ? null
              : _distance.as(LengthUnit.Kilometer, driverLocation, destination);

          final nearingDestination = remainingKm != null && remainingKm <= 2;
          final statusLabel =
              _lastStatus == null ? null : deliveryStatusLabel(_lastStatus!);

          final nearestCity = findNearestEthiopiaCity(
            latitude: driverLocation.latitude,
            longitude: driverLocation.longitude,
          );
          final fallbackLocation = resolveEthiopiaLocation(
            fallback: (_threadData?['startCity'] ?? _threadData?['endCity'])
                ?.toString(),
          );
          final cityName = nearestCity?.city.city ?? fallbackLocation.city;
          final citySubtitle = nearestCity?.city.subtitle.isNotEmpty == true
              ? nearestCity!.city.subtitle
              : fallbackLocation.subtitle;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppPalette.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? AppPalette.darkOutline
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current city',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: isDark
                                ? AppPalette.darkTextSoft
                                : Colors.blueGrey.shade600,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cityName,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    if (citySubtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        citySubtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? AppPalette.darkTextSoft
                                  : Colors.black54,
                            ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _InfoPill(
                          icon: stale
                              ? Icons.warning_amber_rounded
                              : Icons.gps_fixed,
                          label: _updatedLabel(data?.updatedAt),
                          color: stale ? Colors.orange : Colors.green,
                        ),
                        if (statusLabel != null)
                          _InfoPill(
                            icon: Icons.local_shipping_outlined,
                            label: 'Status: $statusLabel',
                            color: isDark
                                ? AppPalette.accent
                                : Colors.blue.shade700,
                          ),
                        if (nearestCity != null)
                          _InfoPill(
                            icon: Icons.place_outlined,
                            label:
                                'Approx. ${nearestCity.distanceKm.toStringAsFixed(0)} km from city center',
                            color: isDark
                                ? AppPalette.darkText
                                : Colors.blueGrey.shade700,
                          ),
                      ],
                    ),
                    if (nearestCity == null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'City shown from the route details until more location data is available.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppPalette.darkTextSoft
                                  : Colors.black54,
                            ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Updates are throttled to reduce map usage.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppPalette.darkTextSoft
                                : Colors.black54,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 240,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _lastMapCenter ?? driverLocation,
                          initialZoom: _mapZoom,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.app',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                width: 60.0,
                                height: 60.0,
                                point: driverLocation,
                                child: const Icon(
                                  Icons.local_shipping,
                                  color: Colors.blue,
                                  size: 40,
                                ),
                              ),
                              if (destination != null)
                                Marker(
                                  width: 42,
                                  height: 42,
                                  point: destination,
                                  child: const Icon(
                                    Icons.flag,
                                    color: Colors.redAccent,
                                    size: 30,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: FloatingActionButton.small(
                          onPressed: () {
                            _mapController.move(driverLocation, _mapZoom + 1);
                          },
                          child: const Icon(Icons.my_location),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppPalette.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark
                        ? AppPalette.darkOutline
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trip progress',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (remainingKm != null)
                      Text(
                        'Remaining: ${remainingKm.toStringAsFixed(1)} km | ETA: ${_etaLabel(remainingKm)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      )
                    else
                      Text(
                        'Destination coordinates unavailable for this load.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      nearingDestination
                          ? 'Checkpoint: Driver is near destination'
                          : 'Checkpoint: En route',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: nearingDestination
                                ? Colors.green
                                : (isDark
                                    ? AppPalette.darkText
                                    : Colors.black87),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkSurfaceRaised : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
