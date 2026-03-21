import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../utils/backend_http.dart';
import '../utils/firestore_service.dart';
import '../app_localizations.dart';

class PostCommentScreen extends StatefulWidget {
  const PostCommentScreen({
    super.key,
    required this.threadDoc,
    this.panelController,
  });

  final String threadDoc;
  final PanelController? panelController;

  @override
  State<PostCommentScreen> createState() => _PostCommentScreenState();
}

class _PostCommentScreenState extends State<PostCommentScreen> {
  final commentController = TextEditingController();
  final carrierNotesController = TextEditingController();

  bool _isSubmitting = false;
  bool _loadingExistingBid = true;
  String? _existingBidId;

  static const double _platformFeeRate = 0.05;
  static const String _defaultCurrency = 'Birr';

  double get _enteredAmount =>
      double.tryParse(commentController.text.replaceAll(',', '').trim()) ?? 0;

  double get _estimatedFee => _enteredAmount * _platformFeeRate;

  double get _estimatedNet =>
      (_enteredAmount - _estimatedFee).clamp(0, double.infinity);

  String _friendlyError(Object e) {
    final msg = e.toString().replaceFirst('Exception: ', '');
    if (msg.contains('already submitted') || msg.contains('already bid')) {
      return 'You already submitted a bid for this load.';
    }
    if (msg.contains('Bidding is closed')) {
      return 'Bidding just closed. Refresh and choose another open load.';
    }
    if (msg.contains('no longer exists') || msg.contains('not found')) {
      return 'This load is no longer available.';
    }
    return msg;
  }

  Map<String, dynamic> _parseNote(String? noteRaw) {
    if (noteRaw == null || noteRaw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(noteRaw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return const {};
    } catch (_) {
      return {'carrierNotes': noteRaw};
    }
  }

  Future<void> _loadExistingBid() async {
    try {
      final data = await BackendHttp.request(
        path: '/api/threads/${widget.threadDoc}/my-bid',
      );

      final bid = data['bid'];
      if (bid is Map<String, dynamic>) {
        final amount = bid['amount'];
        final parsed = _parseNote(bid['note']?.toString());

        _existingBidId = bid['id']?.toString();
        commentController.text = (amount is num)
            ? amount.toString()
            : (amount?.toString() ?? '');
        carrierNotesController.text =
            (parsed['carrierNotes'] ?? '').toString();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingExistingBid = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadExistingBid();
  }

  @override
  void dispose() {
    commentController.dispose();
    carrierNotesController.dispose();
    super.dispose();
  }

  Future<void> submitBid() async {
    if (_isSubmitting) return;
    final localizations = AppLocalizations.of(context);
    final bidAmount =
        double.tryParse(commentController.text.replaceAll(',', '').trim());
    if (bidAmount == null || bidAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.tr('enterValidBidAmount'))),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final hadExisting = _existingBidId != null;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(localizations.tr('submittingBid'))),
    );

    try {
      final bidId = await FirestoreService().upsertMyBid(
        threadId: widget.threadDoc,
        bidAmount: bidAmount,
        currency: _defaultCurrency,
        carrierNotes: carrierNotesController.text,
      );
      _existingBidId = bidId;

      commentController.clear();
      carrierNotesController.clear();

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
            content: Text(hadExisting
                ? localizations.tr('bidUpdated')
                : localizations.tr('bidSubmittedMsg'))),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    if (mounted) setState(() => _isSubmitting = false);

    if (widget.panelController != null) {
      widget.panelController!.close();
    } else {
      if (!mounted) return;
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Column(
      children: [
        if (_loadingExistingBid)
          const Padding(
            padding: EdgeInsets.all(12.0),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  if (widget.panelController != null) {
                    widget.panelController!.close();
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
                child: Text(
                  localizations.tr('cancel'),
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                localizations.tr('bid'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              TextButton(
                onPressed: _isSubmitting ? null : submitBid,
                child: Text(
                  localizations.tr('submit'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const Divider(thickness: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Column(
            children: [
              if (_existingBidId != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'You already bid here. Submitting will update your existing bid.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              TextField(
                controller: commentController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      '${localizations.tr('bidAmountLabel')} ($_defaultCurrency)',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Estimated platform fee (5%): ${_estimatedFee.toStringAsFixed(2)} $_defaultCurrency'),
                    const SizedBox(height: 4),
                    Text(
                      'Estimated net payout: ${_estimatedNet.toStringAsFixed(2)} $_defaultCurrency',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: carrierNotesController,
                decoration: InputDecoration(
                  labelText: localizations.tr('notesOptional'),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

