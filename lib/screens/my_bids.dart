import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:Kora/model/thread_message.dart';
import 'package:Kora/screens/comment_screen.dart';
import 'package:Kora/utils/backend_auth_service.dart';
import 'package:Kora/utils/backend_config.dart';

class MyBidsScreen extends StatefulWidget {
  const MyBidsScreen({super.key});

  @override
  State<MyBidsScreen> createState() => _MyBidsScreenState();
}

class _MyBidsScreenState extends State<MyBidsScreen> {
  final BackendAuthService _authService = BackendAuthService();
  int _reloadToken = 0;

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
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text('My Bids'),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Failed to load bids: ${snapshot.error}'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _reloadToken++),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final bids = snapshot.data ?? const <Map<String, dynamic>>[];
          if (bids.isEmpty) {
            return const Center(
              child: Text(
                'You have not placed any bids yet.',
                style: TextStyle(color: Colors.black54),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: bids.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final bid = bids[index];
              final thread = (bid['load'] as Map<String, dynamic>? ?? const {});
              final amount = (bid['amount'] as num?)?.toDouble() ?? 0.0;
              final status = (bid['status'] ?? 'pending').toString();
              final threadId = (thread['id'] ?? '').toString();
              final threadMessage = _threadToMessage(thread);

              return Card(
                child: ListTile(
                  title: Text('${threadMessage.start} → ${threadMessage.end}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Bid: ${amount.toStringAsFixed(2)} Birr'),
                      const SizedBox(height: 4),
                      Text('Load: ${threadMessage.message}'),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.12),
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
