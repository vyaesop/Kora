import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kora/model/thread_message.dart';
import 'package:kora/screens/comment_screen.dart';
import 'package:kora/utils/error_handler.dart';
import 'package:kora/utils/backend_auth_service.dart';
import 'package:kora/utils/firestore_service.dart';
import 'package:kora/utils/backend_config.dart';
import 'package:kora/app_localizations.dart';

class MyBidsScreen extends StatefulWidget {
  const MyBidsScreen({super.key});

  @override
  State<MyBidsScreen> createState() => _MyBidsScreenState();
}

class _MyBidsScreenState extends State<MyBidsScreen> {
  final BackendAuthService _authService = BackendAuthService();
  int _reloadToken = 0;

  Future<void> _deleteBid(String bidId, String threadId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).tr('withdrawBid')),
        content: Text(AppLocalizations.of(context).tr('withdrawBidConfirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context).tr('withdraw')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirestoreService().deleteBid(threadId: threadId, bidId: bidId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tr('bidWithdrawn'))),
      );
      setState(() => _reloadToken++);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).tr('error')}: ${ErrorHandler.getMessage(e)}')),
      );
    }
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

  Future<List<Map<String, dynamic>>> _fetchBids() async {
    final data = await _authedRequest('/api/bids/me');
    return (data['bids'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  ThreadMessage _threadToMessage(Map<String, dynamic> thread) {
    final createdRaw = thread['createdAt']?.toString();
    final createdAt = createdRaw == null
        ? DateTime.now()
        : DateTime.tryParse(createdRaw) ?? DateTime.now();

    return ThreadMessage(
      id: (thread['id'] ?? '').toString(),
      docId: (thread['id'] ?? '').toString(),
      senderName: 'Load Owner',
      senderProfileImageUrl: '',
      message: (thread['message'] ?? '').toString(),
      timestamp: createdAt,
      likes: const [],
      comments: const [],
      weight: (thread['weight'] as num?)?.toDouble() ?? 0.0,
      type: (thread['type'] ?? '').toString(),
      start: (thread['start'] ?? '').toString(),
      end: (thread['end'] ?? '').toString(),
      packaging: (thread['packaging'] ?? '').toString(),
      weightUnit: (thread['weightUnit'] ?? 'kg').toString(),
      startLat: (thread['startLat'] as num?)?.toDouble() ?? 0.0,
      startLng: (thread['startLng'] as num?)?.toDouble() ?? 0.0,
      endLat: (thread['endLat'] as num?)?.toDouble() ?? 0.0,
      endLng: (thread['endLng'] as num?)?.toDouble() ?? 0.0,
      deliveryStatus: thread['deliveryStatus']?.toString(),
    );
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      case 'completed':
        return 'Completed';
      case 'withdrawn':
        return 'Withdrawn';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'completed':
        return Colors.green;
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      case 'withdrawn':
        return Colors.orange;
      default:
        return Colors.blueGrey;
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
        title: Text(localizations.tr('myBids')),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        key: ValueKey(_reloadToken),
        future: _fetchBids(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

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
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _reloadToken++),
                      icon: const Icon(Icons.refresh),
                      label: Text(localizations.tr('retry')),
                    ),
                  ],
                ),
              ),
            );
          }

          final bids = snapshot.data ?? const <Map<String, dynamic>>[];
          if (bids.isEmpty) {
            return Center(
              child: Text(
                localizations.tr('noBidsPlacedYet'),
                style: const TextStyle(color: Colors.black54),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: bids.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final bid = bids[index];
              final bidId = (bid['id'] ?? '').toString();
              final thread = (bid['load'] as Map<String, dynamic>? ?? const {});
              final amount = (bid['amount'] as num?)?.toDouble() ?? 0.0;
              final status = (bid['status'] ?? 'pending').toString();
              final threadId = (thread['id'] ?? '').toString();
              final threadMessage = _threadToMessage(thread);

              return Card(
                child: ListTile(
                  title: Text('${threadMessage.start} -> ${threadMessage.end}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                          '${localizations.tr('bid')}: ${amount.toStringAsFixed(2)} Birr'),
                      const SizedBox(height: 4),
                      Text('${localizations.tr('loadIndex')}: ${threadMessage.message}'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(status)
                              .withAlpha((0.12 * 255).round()),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(
                            color: _statusColor(status),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (status.toLowerCase() == 'pending')
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteBid(bidId, threadId),
                        ),
                    ],
                  ),
                  onTap: threadId.isEmpty
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CommentScreen(
                                threadId: threadId,
                                message: threadMessage,
                              ),
                            ),
                          );
                        },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

