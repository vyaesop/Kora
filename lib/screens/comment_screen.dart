import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:Kora/model/thread_message.dart';
import 'package:Kora/widgets/agreed_price_banner.dart';
import 'package:Kora/widgets/active_job_controls.dart';
import 'package:Kora/widgets/driver_status_controls.dart';
import 'package:Kora/widgets/place_bid_widget.dart';
import 'package:Kora/utils/firestore_service.dart';
import 'package:Kora/utils/backend_auth_service.dart';
import 'package:Kora/utils/backend_http.dart';
import 'package:Kora/app_localizations.dart';

class CommentScreen extends StatefulWidget {
  final String threadId;
  final ThreadMessage message;

  const CommentScreen({
    super.key,
    required this.threadId,
    required this.message,
  });

  @override
  State<CommentScreen> createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  final _authService = BackendAuthService();

  bool _loading = true;
  String? _error;
  String? _currentUserId;
  Map<String, dynamic>? _thread;
  List<Map<String, dynamic>> _bids = const [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final userId = await _authService.getCurrentUserId();
    if (!mounted) return;
    setState(() => _currentUserId = userId);

    await _refresh(showLoader: true);

    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refresh(showLoader: false);
    });
  }

  Future<void> _refresh({required bool showLoader}) async {
    if (showLoader && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final threadData = await BackendHttp.request(path: '/api/threads/${widget.threadId}');
      final bidsData = await BackendHttp.request(path: '/api/threads/${widget.threadId}/bids');

      final thread = threadData['thread'] as Map<String, dynamic>?;
      final bidsRaw = bidsData['bids'];
      final bids = (bidsRaw is List)
          ? bidsRaw.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];

      bids.sort((a, b) {
        final aAmount = (a['amount'] as num?)?.toDouble() ?? 0;
        final bAmount = (b['amount'] as num?)?.toDouble() ?? 0;
        return aAmount.compareTo(bAmount);
      });

      if (!mounted) return;
      setState(() {
        _thread = thread;
        _bids = bids;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Map<String, dynamic> _parseBidNote(dynamic note) {
    if (note == null) return const {};
    final text = note.toString();
    if (text.isEmpty) return const {};
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      return const {};
    } catch (_) {
      return {'carrierNotes': text};
    }
  }

  Future<void> _acceptBid(Map<String, dynamic> bid) async {
    final thread = _thread;
    if (thread == null) return;

    try {
      await FirestoreService().acceptBid(
        threadId: widget.threadId,
        bidId: (bid['id'] ?? '').toString(),
        acceptedCarrierId: (bid['driverId'] ?? '').toString(),
        finalPrice: (bid['amount'] as num?)?.toDouble() ?? 0,
        closeBidding: true,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bid accepted successfully.')),
      );
      await _refresh(showLoader: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept bid: $e')),
      );
    }
  }

  Future<void> _deleteBid(Map<String, dynamic> bid) async {
    try {
      await FirestoreService().deleteBid(
        threadId: widget.threadId,
        bidId: (bid['id'] ?? '').toString(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bid deleted.')),
      );
      await _refresh(showLoader: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete bid: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(localizations.tr('feed'))),
        body: Center(child: Text(_error!)),
      );
    }

    final thread = _thread;
    if (thread == null) {
      return Scaffold(
        appBar: AppBar(title: Text(localizations.tr('feed'))),
        body: const Center(child: Text('Thread not found.')),
      );
    }

    final ownerId = (thread['ownerId'] ?? '').toString();
    final isShipper = _currentUserId != null && _currentUserId == ownerId;
    final deliveryStatus = (thread['deliveryStatus'] ?? 'pending_bids').toString();
    final isBiddingClosed = deliveryStatus != 'pending_bids';

    Map<String, dynamic>? acceptedBid;
    for (final bid in _bids) {
      final status = (bid['status'] ?? '').toString().toLowerCase();
      if (status == 'accepted' || status == 'completed') {
        acceptedBid = bid;
        break;
      }
    }

    final acceptedDriverId = (acceptedBid?['driverId'] ?? '').toString();
    final acceptedBidId = (acceptedBid?['id'] ?? '').toString();
    final acceptedNote = _parseBidNote(acceptedBid?['note']);
    final finalPrice = (acceptedNote['finalPrice'] as num?)?.toDouble() ??
        ((acceptedBid?['amount'] as num?)?.toDouble() ?? 0);
    final currency = (acceptedNote['currency'] ?? thread['weightUnit'] ?? 'Birr').toString();

    final isAcceptedDriver = _currentUserId != null && _currentUserId == acceptedDriverId;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text(localizations.tr('feed')),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (isBiddingClosed && acceptedBid != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: AgreedPriceBanner(finalPrice: finalPrice, currency: currency),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                child: ListTile(
                  title: Text(widget.message.message),
                  subtitle: Text('${widget.message.start} → ${widget.message.end}'),
                ),
              ),
            ),
            Expanded(
              child: _bids.isEmpty
                  ? const Center(child: Text('No bids yet.'))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemBuilder: (context, index) {
                        final bid = _bids[index];
                        final bidDriverId = (bid['driverId'] ?? '').toString();
                        final amount = (bid['amount'] as num?)?.toDouble() ?? 0;
                        final status = (bid['status'] ?? 'pending').toString();
                        final note = _parseBidNote(bid['note']);
                        final carrierNotes = (note['carrierNotes'] ?? '').toString();

                        final canAccept = isShipper &&
                            !isBiddingClosed &&
                            status.toLowerCase() == 'pending';
                        final canDelete = !isShipper &&
                            bidDriverId == _currentUserId &&
                            status.toLowerCase() == 'pending';

                        return ListTile(
                          tileColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          title: Text('Bid: ${amount.toStringAsFixed(2)} ${note['currency'] ?? 'Birr'}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Driver: $bidDriverId'),
                              if (carrierNotes.isNotEmpty) Text(carrierNotes),
                              Text('Status: $status'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (canAccept)
                                TextButton(
                                  onPressed: () => _acceptBid(bid),
                                  child: const Text('Accept'),
                                ),
                              if (canDelete)
                                TextButton(
                                  onPressed: () => _deleteBid(bid),
                                  child: const Text('Delete'),
                                ),
                            ],
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemCount: _bids.length,
                    ),
            ),
            if (!isShipper && !isBiddingClosed)
              Container(
                color: Colors.grey.shade50,
                child: PlaceBidWidget(threadId: widget.threadId, currency: currency),
              ),
            if (isBiddingClosed && acceptedBid != null)
              Container(
                color: Colors.grey.shade50,
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    ActiveJobControls(
                      isShipper: isShipper,
                      threadId: widget.threadId,
                      carrierId: acceptedDriverId,
                      deliveryStatus: deliveryStatus,
                      bidId: acceptedBidId,
                      driverId: acceptedDriverId,
                      ownerId: ownerId,
                    ),
                    if (isAcceptedDriver)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: DriverStatusControls(
                          threadId: widget.threadId,
                          currentStatus: deliveryStatus,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
