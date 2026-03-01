import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Kora/utils/backend_auth_service.dart';
import 'package:Kora/utils/backend_config.dart';

class DriverLocationSnapshot {
  final LatLng? location;
  final DateTime? updatedAt;
  const DriverLocationSnapshot({this.location, this.updatedAt});
}

class TrackDriverMapScreen extends StatefulWidget {
  final String driverId;
  final String loadId;
  const TrackDriverMapScreen(
      {Key? key, required this.driverId, required this.loadId})
      : super(key: key);

  @override
  State<TrackDriverMapScreen> createState() => _TrackDriverMapScreenState();
}

class _TrackDriverMapScreenState extends State<TrackDriverMapScreen> {
  final MapController _mapController = MapController();
  final Distance _distance = const Distance();
  final BackendAuthService _authService = BackendAuthService();

  DriverLocationSnapshot? _driverSnapshot;
  Map<String, dynamic>? _threadData;
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _refresh(showLoader: false));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<Map<String, dynamic>> _authedRequest(String path) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not signed in');
    }

    final uri = Uri.parse('${BackendConfig.baseUrl}$path');
    final client = HttpClient();
    try {
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final res = await req.close();
      final raw = await utf8.decoder.bind(res).join();
      final data = raw.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] == false) {
        throw Exception((data['error'] ?? 'Request failed').toString());
      }
      return data;
    } finally {
      client.close(force: true);
    }
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

  Future<void> _refresh({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final locationData = await _authedRequest('/api/drivers/${widget.driverId}/location');
      final threadData = await _authedRequest('/api/threads/${widget.loadId}');
      final snapshot = _parseLocation(locationData['location'] as Map<String, dynamic>?);

      if (!mounted) return;
      setState(() {
        _driverSnapshot = snapshot;
        _threadData = threadData['thread'] as Map<String, dynamic>?;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
      debugPrint('TrackDriverMapScreen refresh error: $e');
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
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Track Driver'),
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
                child: Text('Unable to load live location right now. $_error'),
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
              final destination =
                  hasDestination ? LatLng(endLat, endLng) : null;
              final remainingKm = destination == null
                  ? null
                  : _distance.as(
                      LengthUnit.Kilometer, driverLocation, destination);

              final nearingDestination =
                  remainingKm != null && remainingKm <= 2;

              return Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      center: driverLocation,
                      zoom: 13.0,
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
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Card(
                      color: stale ? Colors.orange.shade50 : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                    stale
                                        ? Icons.warning_amber_rounded
                                        : Icons.gps_fixed,
                                    color:
                                        stale ? Colors.orange : Colors.green),
                                const SizedBox(width: 8),
                                Expanded(
                                    child:
                                        Text(_updatedLabel(data?.updatedAt))),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (remainingKm != null)
                              Text(
                                'Remaining: ${remainingKm.toStringAsFixed(1)} km • ETA: ${_etaLabel(remainingKm)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              )
                            else
                              const Text(
                                'Destination coordinates unavailable for this load.',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              nearingDestination
                                  ? 'Checkpoint: Driver is near destination'
                                  : 'Checkpoint: En route',
                              style: TextStyle(
                                color: nearingDestination
                                    ? Colors.green
                                    : Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: FloatingActionButton.small(
                      onPressed: () {
                        _mapController.move(driverLocation, 14);
                      },
                      child: const Icon(Icons.my_location),
                    ),
                  ),
                ],
              );
        },
      ),
    );
  }
}
