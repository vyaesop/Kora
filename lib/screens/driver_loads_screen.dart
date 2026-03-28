import 'package:flutter/material.dart';

import 'package:kora/utils/firestore_service.dart';
import 'package:kora/app_localizations.dart';
import 'package:kora/utils/backend_http.dart';

class DriverLoadsScreen extends StatelessWidget {
  final String driverId;
  const DriverLoadsScreen({super.key, required this.driverId});

  Future<List<Map<String, dynamic>>> _fetchOpenLoads() async {
    final data = await BackendHttp.request(
      path: '/api/threads?limit=20',
      auth: false,
      cacheTtl: const Duration(seconds: 20),
    );
    return (data['threads'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((thread) =>
            (thread['deliveryStatus'] ?? 'pending_bids').toString() ==
            'pending_bids')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
              return _buildLoadCard(
                  context, (load['id'] ?? '').toString(), load, localizations);
            },
          );
        },
      ),
    );
  }

  Widget _buildLoadCard(BuildContext context, String threadId,
      Map<String, dynamic> load, AppLocalizations localizations) {
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
        title: Text(title.isEmpty ? localizations.tr('availableLoad') : title),
        subtitle: Text(
            '${localizations.tr('from')}: $start\n${localizations.tr('to')}: $end\n$bidsCount ${localizations.tr('bidsSoFar')}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(localizations.tr('openStatus'),
                style:
                    const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ElevatedButton(
              onPressed: () => _showBidDialog(context, threadId, localizations),
              child: Text(localizations.tr('bid')),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _showBidDialog(BuildContext context, String threadId,
      AppLocalizations localizations) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localizations.tr('placeBid')),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: '${localizations.tr('enterBidAmount')} (Birr)',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(localizations.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(localizations.tr('submit')),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;
    final amount = double.tryParse(result.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.tr('enterValidAmount'))),
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
        SnackBar(content: Text(localizations.tr('bidSubmitted'))),
      );
    }
  }
}

class BidButton extends StatefulWidget {
  final String threadId;
  final String driverId;
  const BidButton({super.key, required this.threadId, required this.driverId});

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
    final localizations = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration:
                InputDecoration(labelText: localizations.tr('yourBid')),
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
                        SnackBar(
                            content:
                                Text(localizations.tr('enterValidAmount'))),
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
              : Text(localizations.tr('submitBid')),
        ),
      ],
    );
  }
}

