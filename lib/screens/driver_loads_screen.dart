import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';

import 'package:Kora/utils/firestore_service.dart';
import 'package:Kora/app_localizations.dart';
import 'package:Kora/utils/backend_auth_service.dart';
import 'package:Kora/utils/backend_config.dart';

class DriverLoadsScreen extends StatelessWidget {
  final String driverId;
  const DriverLoadsScreen({Key? key, required this.driverId}) : super(key: key);

  Future<List<Map<String, dynamic>>> _fetchOpenLoads() async {
    final token = await BackendAuthService().getToken();
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
          .where((thread) => (thread['deliveryStatus'] ?? 'pending_bids').toString() == 'pending_bids')
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
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(localizations.tr('availableLoads')),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchOpenLoads(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final loads = snapshot.data ?? const <Map<String, dynamic>>[];
          if (loads.isEmpty) {
            return Center(child: Text(localizations.tr('noLoadsAvailable')));
          }
          return ListView.builder(
            itemCount: loads.length,
            itemBuilder: (context, index) {
              final load = loads[index];
              return _buildLoadCard(context, (load['id'] ?? '').toString(), load);
            },
          );
        },
      ),
    );
  }

  Widget _buildLoadCard(
      BuildContext context, String threadId, Map<String, dynamic> load) {
    final title =
        (load['description'] ?? load['message'] ?? '').toString().trim();
    final start = (load['start'] ??
            load['origin'] ??
            load['startCity'] ??
            'Unknown origin')
        .toString();
    final end = (load['end'] ??
            load['destination'] ??
            load['endCity'] ??
            'Unknown destination')
        .toString();
    final bidsCount = (load['bids_count'] as num?)?.toInt() ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: ListTile(
        title: Text(title.isEmpty ? 'Available Load' : title),
        subtitle: Text('From: $start → To: $end\n$bidsCount bids so far'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Open',
                style:
                    TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ElevatedButton(
              onPressed: () => _showBidDialog(context, threadId),
              child: const Text('Bid'),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _showBidDialog(BuildContext context, String threadId) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Place Bid'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: 'Enter bid amount (Birr)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;
    final amount = double.tryParse(result.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid positive bid amount.')),
        );
      }
      return;
    }

    try {
      await FirestoreService().upsertMyBid(
        threadId: threadId,
        bidAmount: amount,
        currency: 'Birr',
        carrierNotes: '',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bid submitted.')),
      );
    }
  }
}

class BidButton extends StatefulWidget {
  final String threadId;
  final String driverId;
  const BidButton({Key? key, required this.threadId, required this.driverId})
      : super(key: key);

  @override
  State<BidButton> createState() => _BidButtonState();
}

class _BidButtonState extends State<BidButton> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Your Bid'),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _loading
              ? null
              : () async {
                  setState(() => _loading = true);
                  final amount = double.tryParse(
                      _controller.text.replaceAll(',', '').trim());
                  if (amount == null || amount <= 0) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Enter a valid positive bid amount.')),
                      );
                    }
                    setState(() => _loading = false);
                    return;
                  }
                  await FirestoreService().upsertMyBid(
                    threadId: widget.threadId,
                    bidAmount: amount,
                    currency: 'Birr',
                    carrierNotes: '',
                  );
                  setState(() => _loading = false);
                },
          child: _loading
              ? const CircularProgressIndicator()
              : const Text('Submit Bid'),
        ),
      ],
    );
  }
}
