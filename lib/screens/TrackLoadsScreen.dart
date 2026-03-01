import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';

import 'package:Kora/utils/delivery_status.dart';
import 'package:Kora/app_localizations.dart';
import 'package:Kora/utils/backend_auth_service.dart';
import 'package:Kora/utils/backend_config.dart';

class TrackLoadsScreen extends StatefulWidget {
  const TrackLoadsScreen({Key? key}) : super(key: key);

  @override
  State<TrackLoadsScreen> createState() => _TrackLoadsScreenState();
}

class _TrackLoadsScreenState extends State<TrackLoadsScreen> {
  int _reloadToken = 0;
  final BackendAuthService _authService = BackendAuthService();

  void _retry() {
    setState(() {
      _reloadToken++;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchMyLoads() async {
    final token = await _authService.getToken();
    final userId = await _authService.getCurrentUserId();
    if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
      throw Exception('Not signed in');
    }

    final uri = Uri.parse('${BackendConfig.baseUrl}/api/threads');
    final client = HttpClient();
    try {
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final res = await req.close();
      final raw = await utf8.decoder.bind(res).join();
      final data = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw) as Map<String, dynamic>;
      if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] == false) {
        throw Exception((data['error'] ?? 'Request failed').toString());
      }

      final list = (data['threads'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .where((thread) => (thread['ownerId'] ?? '').toString() == userId)
          .toList();
      return list;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(localizations.tr('activeLoads')),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        key: ValueKey(_reloadToken),
        future: _fetchMyLoads(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(localizations.tr('activeLoads')),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: Text(localizations.tr('retry')),
                    ),
                  ],
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final loads = snapshot.data ?? const <Map<String, dynamic>>[];
          if (loads.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(localizations.tr('noLoadsPosted')),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: Text(localizations.tr('refresh')),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: loads.length,
            itemBuilder: (context, index) {
                  final load = loads[index];
                  final bidCount = (load['bids'] as List<dynamic>?)?.length ??
                      ((load['bids_count'] as num?)?.toInt() ?? 0);
                  final title = (load['description'] ?? load['message'] ?? '').toString().trim();
                  final end = (load['end'] ?? load['destination'] ?? load['endCity'] ?? 'Unknown destination').toString();
                  final status = deliveryStatusLabel((load['deliveryStatus'] ?? 'pending_bids').toString());
                  final pickupText = (load['pickupWindowStart'] ?? 'N/A').toString();
                  final deliveryText = (load['deliveryWindowEnd'] ?? 'N/A').toString();

                  return ListTile(
                    title: Text(title.isEmpty ? 'Load ${index + 1}' : title),
                    subtitle: Text('${localizations.tr('to')}: $end\n${localizations.tr('status')}: $status\nPickup: $pickupText • Delivery: $deliveryText'),
                    trailing: Text('$bidCount bids'),
                    isThreeLine: true,
                  );
            },
          );
        },
      ),
    );
  }
}