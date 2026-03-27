import 'package:flutter/material.dart';
import 'dart:convert';

import '../utils/backend_http.dart';
import '../app_localizations.dart';

class PlaceBidWidget extends StatefulWidget {
  final String threadId;
  final String currency;
  const PlaceBidWidget({super.key, required this.threadId, required this.currency});

  @override
  State<PlaceBidWidget> createState() => _PlaceBidWidgetState();
}

class _PlaceBidWidgetState extends State<PlaceBidWidget> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  bool _loading = false;
  bool _loadingExistingBid = true;
  String? _existingBidId;

  static const double _platformFeeRate = 0.05;

  double get _enteredAmount =>
      double.tryParse(_amountController.text.replaceAll(',', '').trim()) ?? 0;

  double get _estimatedFee => _enteredAmount * _platformFeeRate;

  double get _estimatedNet => (_enteredAmount - _estimatedFee).clamp(0, double.infinity);

  String _friendlyError(Object e) {
    final msg = e.toString().replaceFirst('Exception: ', '');
    if (msg.contains('already placed a bid')) {
      return 'You already bid on this load. Open the thread to update your decision context.';
    }
    if (msg.contains('Bidding is closed')) {
      return 'Bidding closed while submitting. Refresh thread details and pick another load.';
    }
    if (msg.contains('no longer exists')) {
      return 'This load was removed before your bid was submitted.';
    }
    return msg;
  }

  Future<Map<String, dynamic>> _authedRequest({
    required String path,
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    return BackendHttp.request(
      path: path,
      method: method,
      body: body,
      forceRefresh: method.toUpperCase() != 'GET',
    );
  }

  Map<String, dynamic> _parseBidNote(String? note) {
    if (note == null || note.isEmpty) return const {};
    try {
      final decoded = jsonDecode(note);
      if (decoded is Map<String, dynamic>) return decoded;
      return const {};
    } catch (_) {
      return {'carrierNotes': note};
    }
  }

  Future<void> _loadExistingBid() async {
    try {
      final data = await _authedRequest(path: '/api/threads/${widget.threadId}/my-bid');
      final bid = data['bid'];

      if (bid is Map<String, dynamic>) {
        final amount = bid['amount'];
        final parsedNote = _parseBidNote(bid['note']?.toString());
        _existingBidId = bid['id']?.toString();
        _amountController.text = (amount is num)
            ? amount.toString()
            : (amount?.toString() ?? '');
        _notesController.text = (parsedNote['carrierNotes'] ?? '').toString();
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
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _placeBid() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final localizations = AppLocalizations.of(context);
    final hadExisting = _existingBidId != null;
    try {
      final messenger = ScaffoldMessenger.of(context);
      final result = await _authedRequest(
        path: '/api/threads/${widget.threadId}/my-bid',
        method: 'PUT',
        body: {
          'amount': _enteredAmount,
          'currency': widget.currency,
          'carrierNotes': _notesController.text.trim(),
        },
      );
      final bid = result['bid'] as Map<String, dynamic>? ?? const {};
      final bidId = (bid['id'] ?? '').toString();
      _existingBidId = bidId;
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
            content: Text(hadExisting
                ? localizations.tr('bidUpdatedSuccess')
                : localizations.tr('bidPlacedSuccess'))),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(e))),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: _loadingExistingBid
          ? const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            )
          : Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                child: Text(
                  localizations.tr('alreadyBidUpdateNotice'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '${localizations.tr('bidAmountLabel')} (${widget.currency})',
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return localizations.tr('enterAmount');
                }
                final num? parsed = num.tryParse(value.replaceAll(',', '').trim());
                if (parsed == null || parsed <= 0) {
                  return localizations.tr('enterValidAmount');
                }
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
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
                      '${localizations.tr('estimatedPlatformFee')}: ${_estimatedFee.toStringAsFixed(2)} ${widget.currency}'),
                  const SizedBox(height: 4),
                  Text(
                    '${localizations.tr('estimatedNetPayout')}: ${_estimatedNet.toStringAsFixed(2)} ${widget.currency}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: localizations.tr('notesOptional'),
                border: const OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _placeBid,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_existingBidId == null
                        ? localizations.tr('placeBid')
                        : localizations.tr('updateBid')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
