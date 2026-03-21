import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';

import 'package:kora/utils/delivery_status.dart';
import 'package:kora/utils/error_handler.dart';
import 'package:kora/app_localizations.dart';
import 'package:kora/utils/backend_auth_service.dart';
import 'package:kora/utils/backend_config.dart';

class TrackLoadsScreen extends StatefulWidget {
  final bool showBack;
  const TrackLoadsScreen({super.key, this.showBack = true});

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

  Future<void> _deleteLoad(String loadId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).tr('deleteLoad')),
        content: Text(AppLocalizations.of(context).tr('deleteLoadConfirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context).tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = await _authService.getToken();
      if (token == null) throw Exception('Not signed in');

      final uri = Uri.parse('${BackendConfig.baseUrl}/api/threads/$loadId');
      final client = HttpClient();
      final req = await client.openUrl('DELETE', uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final res = await req.close();
      
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Failed to delete load');
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tr('loadDeleted'))),
      );
      _retry();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).tr('error')}: ${ErrorHandler.getMessage(e)}')),
      );
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
        leading: widget.showBack
            ? IconButton(
                tooltip: localizations.tr('back'),
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              )
            : null,
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
                    Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    Text(
                      ErrorHandler.getMessage(snapshot.error!),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
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

                  final loadId = (load['id'] ?? '').toString();

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text(title.isEmpty
                          ? '${localizations.tr('loadIndex')} ${index + 1}'
                          : title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('${localizations.tr('to')}: $end'),
                          Text('${localizations.tr('status')}: $status'),
                          Text('${localizations.tr('pickup')}: $pickupText'),
                          Text('${localizations.tr('delivery')}: $deliveryText'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$bidCount ${localizations.tr('bidsCount')}'),
                          const SizedBox(width: 8),
                          if (status.toLowerCase() != 'completed' && status.toLowerCase() != 'cancelled')
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteLoad(loadId),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
            },
          );
        },
      ),
    );
  }
}
