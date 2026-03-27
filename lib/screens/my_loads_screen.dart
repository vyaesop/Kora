import 'package:flutter/material.dart';

import 'package:kora/utils/delivery_status.dart';
import 'package:kora/app_localizations.dart';
import 'package:kora/utils/backend_http.dart';

class MyLoadsScreen extends StatefulWidget {
  final String cargoUserId;
  const MyLoadsScreen({super.key, required this.cargoUserId});

  @override
  State<MyLoadsScreen> createState() => _MyLoadsScreenState();
}

class _MyLoadsScreenState extends State<MyLoadsScreen> {
  int _reloadToken = 0;

  void _retry() {
    setState(() {
      _reloadToken++;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchLoads() async {
    final data = await BackendHttp.request(
      path: '/api/users/${widget.cargoUserId}/threads',
      cacheTtl: const Duration(seconds: 20),
      forceRefresh: _reloadToken > 0,
    );
    return (data['threads'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
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
          tooltip: localizations.tr('back'),
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
                title: Text(
                    title.isEmpty ? '${localizations.tr('loadIndex')} ${index + 1}' : title),
                subtitle: Text('${localizations.tr('from')}: $start\n${localizations.tr('to')}: $end\n${localizations.tr('status')}: $status'),
                trailing: Text('$bidsCount ${localizations.tr('bidsCount')}'),
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

