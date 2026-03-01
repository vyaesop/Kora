import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';

import 'package:Kora/utils/delivery_status.dart';
import 'package:Kora/app_localizations.dart';
import 'package:Kora/utils/backend_auth_service.dart';
import 'package:Kora/utils/backend_config.dart';

class MyLoadsScreen extends StatefulWidget {
  final String cargoUserId;
  const MyLoadsScreen({Key? key, required this.cargoUserId}) : super(key: key);

  @override
  State<MyLoadsScreen> createState() => _MyLoadsScreenState();
}

class _MyLoadsScreenState extends State<MyLoadsScreen> {
  int _reloadToken = 0;
  final BackendAuthService _authService = BackendAuthService();

  void _retry() {
    setState(() {
      _reloadToken++;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchLoads() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
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

      return (data['threads'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .where((thread) => (thread['ownerId'] ?? '').toString() == widget.cargoUserId)
          .toList();
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
        title: Text(localizations.tr('myLoads')),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        key: ValueKey(_reloadToken),
        future: _fetchLoads(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
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
              final title = (load['description'] ?? load['message'] ?? '').toString().trim();
              final start = (load['start'] ?? load['origin'] ?? load['startCity'] ?? 'Unknown origin').toString();
              final end = (load['end'] ?? load['destination'] ?? load['endCity'] ?? 'Unknown destination').toString();
              final bidsCount = (load['bids_count'] as num?)?.toInt() ?? 0;
              final status = deliveryStatusLabel((load['deliveryStatus'] ?? 'pending_bids').toString());

              return ListTile(
                title: Text(title.isEmpty ? 'Load ${index + 1}' : title),
                subtitle: Text('${localizations.tr('from')}: $start\n${localizations.tr('to')}: $end\n${localizations.tr('status')}: $status'),
                trailing: Text('$bidsCount bids'),
                isThreeLine: true,
                onTap: () {
                  // Intentionally left lightweight; detailed management happens in CommentScreen.
                },
              );
            },
          );
        },
      ),
    );
  }
}
