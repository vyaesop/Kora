import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kora/utils/app_theme.dart';
import 'package:kora/screens/track_driver_map_screen.dart';
import 'package:kora/screens/shipment_chat_screen.dart';
import 'package:kora/utils/backend_auth_service.dart';
import 'package:kora/utils/backend_config.dart';
import 'package:kora/app_localizations.dart';
import 'package:kora/utils/delivery_status.dart';

Future<Map<String, dynamic>> _authedRequest({
  required String path,
  String method = 'GET',
  Map<String, dynamic>? body,
}) async {
  final token = await BackendAuthService().getToken();
  if (token == null || token.isEmpty) {
    throw Exception('Not signed in');
  }

  final uri = Uri.parse('${BackendConfig.baseUrl}$path');
  final client = HttpClient();
  try {
    final req = await client.openUrl(method, uri);
    req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');

    if (body != null) {
      req.add(utf8.encode(jsonEncode(body)));
    }

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

class ActiveJobControls extends StatelessWidget {
  final bool isShipper;
  final String threadId;
  final String carrierId;
  final String deliveryStatus;
  final String bidId;
  final String driverId;
  final String ownerId;
  const ActiveJobControls({
    super.key,
    required this.isShipper,
    required this.threadId,
    required this.carrierId,
    required this.deliveryStatus,
    required this.bidId,
    required this.driverId,
    required this.ownerId,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stages = const [
      'accepted',
      'driving_to_location',
      'picked_up',
      'on_the_road',
      'delivered',
    ];
    final currentStageIndex = stages.indexOf(deliveryStatus);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkCard : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppPalette.darkOutline : const Color(0xFFDBEAFE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppPalette.darkSurfaceRaised
                      : Colors.white.withAlpha((0.74 * 255).round()),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.local_shipping_outlined,
                  color: isDark ? AppPalette.accent : Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shipment actions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Current stage: ${deliveryStatusLabel(deliveryStatus)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? AppPalette.darkTextSoft : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: stages.asMap().entries.map((entry) {
              final index = entry.key;
              final status = entry.value;
              final isActive = index <= currentStageIndex;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? (isDark
                          ? AppPalette.accent.withAlpha((0.18 * 255).round())
                          : Colors.blue.shade100)
                      : (isDark
                          ? AppPalette.darkSurfaceRaised
                          : Colors.white.withAlpha((0.74 * 255).round())),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  deliveryStatusLabel(status),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? (isDark ? AppPalette.darkText : Colors.blue.shade900)
                        : (isDark
                            ? AppPalette.darkTextSoft
                            : Colors.blueGrey.shade600),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (isShipper)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TrackDriverMapScreen(
                          driverId: driverId,
                          loadId: threadId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.location_on),
                  label: Text(localizations.tr('trackDriver')),
                ),
              ElevatedButton.icon(
                onPressed: () {
                  _launchMessage(context, isShipper ? carrierId : ownerId);
                },
                icon: const Icon(Icons.message),
                label: Text(
                  isShipper
                      ? localizations.tr('messageCarrier')
                      : localizations.tr('messageShipper'),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShipmentChatScreen(
                        threadId: threadId,
                        peerId: isShipper ? carrierId : ownerId,
                        peerLabel: isShipper
                            ? AppLocalizations.of(context).tr('driverLabel')
                            : AppLocalizations.of(context).tr('cargoLabel'),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text(localizations.tr('inAppChat')),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _launchCall(context, isShipper ? driverId : ownerId);
                },
                icon: const Icon(Icons.call),
                label: Text(isShipper
                    ? localizations.tr('callDriver')
                    : localizations.tr('callShipper')),
              ),
              if (isShipper)
                ElevatedButton.icon(
                  onPressed: _canMarkDelivered(deliveryStatus)
                      ? () => _completeDeliveryWithProof(context)
                      : null,
                  icon: const Icon(Icons.task_alt),
                  label: Text(localizations.tr('markDelivered')),
                ),
              OutlinedButton.icon(
                onPressed: () => _reportIssue(context),
                icon: const Icon(Icons.report_problem_outlined),
                label: Text(localizations.tr('reportIssue')),
              ),
            ],
          ),
          if (isShipper && deliveryStatus == 'delivered') ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppPalette.darkSurfaceRaised : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color:
                      isDark ? AppPalette.darkOutline : const Color(0xFFFDE68A),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.star_outline,
                      color: Colors.amber.shade700, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Delivery complete. Leave a driver rating to close the loop.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => RatingDialog(
                          driverId: driverId,
                          bidId: bidId,
                          ownerId: ownerId,
                        ),
                      );
                    },
                    child: Text(localizations.tr('rateDriver')),
                  ),
                ],
              ),
            ),
          ] else if (!isShipper && deliveryStatus == 'delivered') ...[
            const SizedBox(height: 16),
            Text(
              'Delivery has been completed. The shipper can now leave a rating.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? AppPalette.darkTextSoft : Colors.black54,
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _canMarkDelivered(String status) {
    const allowed = {
      'accepted',
      'driving_to_location',
      'picked_up',
      'on_the_road',
    };
    return allowed.contains(status);
  }

  Future<void> _completeDeliveryWithProof(BuildContext context) async {
    if (bidId.isEmpty) {
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(localizations.tr('cannotCompleteDeliveryMissingBid'))),
      );
      return;
    }

    final proof = await showDialog<_ProofData>(
      context: context,
      builder: (ctx) => const _DeliveryProofDialog(),
    );
    if (proof == null) return;

    try {
      await _authedRequest(
        path: '/api/threads/$threadId/delivery/complete',
        method: 'PATCH',
        body: {
          'bidId': bidId,
          'receiverName': proof.receiverName,
          'deliveryNotes': proof.deliveryNotes,
          'photoUrl': proof.photoUrl,
        },
      );

      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => RatingDialog(driverId: driverId, bidId: bidId, ownerId: ownerId),
      );
    } catch (e) {
      if (!context.mounted) return;
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${localizations.tr('failedCompleteDelivery')}$e')),
      );
    }
  }

  Future<void> _reportIssue(BuildContext context) async {
    final details = await showDialog<_IssueData>(
      context: context,
      builder: (_) => const _ReportIssueDialog(),
    );
    if (details == null) return;

    try {
      await _authedRequest(
        path: '/api/threads/$threadId/disputes',
        method: 'POST',
        body: {
          'category': details.category,
          'details': details.details,
          'bidId': bidId,
          'driverId': driverId,
          'ownerId': ownerId,
          'reporterRole': isShipper ? 'cargo' : 'driver',
        },
      );

      if (!context.mounted) return;
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.tr('issueReported'))),
      );
    } catch (e) {
      if (!context.mounted) return;
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${localizations.tr('failedReportIssue')}$e')),
      );
    }
  }

  Future<String?> _getPhoneNumber(String userId) async {
    final data = await _authedRequest(path: '/api/users/$userId/contact');
    final user = data['user'] as Map<String, dynamic>?;
    if (user == null) return null;
    return (user['phoneNumber'] ?? user['phone'])?.toString();
  }

  Future<void> _launchMessage(BuildContext context, String userId) async {
    final phone = await _getPhoneNumber(userId);
    if (!context.mounted) return;
    if (phone == null || phone.isEmpty) {
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.tr('noPhoneForMessaging'))),
      );
      return;
    }
    final localizations = AppLocalizations.of(context);
    final proceed = await _confirmAction(
      context,
      title: localizations.tr('confirmMessageTitle'),
      body:
          '${localizations.tr('confirmMessageBody')} $phone',
    );
    if (!context.mounted) return;
    if (!proceed) return;
    final uri = Uri(scheme: 'sms', path: phone);
    final launched = await launchUrl(uri);
    if (!context.mounted) return;
    if (!launched) {
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.tr('unableOpenMessaging'))),
      );
    }
  }

  Future<void> _launchCall(BuildContext context, String userId) async {
    final phone = await _getPhoneNumber(userId);
    if (!context.mounted) return;
    if (phone == null || phone.isEmpty) {
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.tr('noPhoneForCalling'))),
      );
      return;
    }
    final localizations = AppLocalizations.of(context);
    final proceed = await _confirmAction(
      context,
      title: localizations.tr('confirmCallTitle'),
      body:
          '${localizations.tr('confirmCallBody')} $phone',
    );
    if (!context.mounted) return;
    if (!proceed) return;
    final uri = Uri(scheme: 'tel', path: phone);
    final launched = await launchUrl(uri);
    if (!context.mounted) return;
    if (!launched) {
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.tr('unableOpenDialer'))),
      );
    }
  }

  Future<bool> _confirmAction(
    BuildContext context, {
    required String title,
    required String body,
  }) async {
    final localizations = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(localizations.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(localizations.tr('continue')),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class RatingDialog extends StatefulWidget {
  final String driverId;
  final String bidId;
  final String ownerId;
  const RatingDialog({
    super.key,
    required this.driverId,
    required this.bidId,
    required this.ownerId,
  });

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  double _rating = 4.0;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(localizations.tr('rateDriver')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(localizations.tr('rateDriverPrompt')),
          Slider(
            value: _rating,
            min: 1,
            max: 5,
            divisions: 4,
            label: _rating.toStringAsFixed(1),
            onChanged: (value) {
              setState(() {
                _rating = value;
              });
            },
          ),
          TextField(
            controller: _commentController,
            decoration: InputDecoration(
              labelText: localizations.tr('optionalFeedback'),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _submitRating(context);
          },
          child: Text(localizations.tr('submit')),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(localizations.tr('cancel')),
        ),
      ],
    );
  }

  Future<void> _submitRating(BuildContext context) async {
    try {
      await _authedRequest(
        path: '/api/users/${widget.driverId}/ratings',
        method: 'POST',
        body: {
          'bidId': widget.bidId,
          'rating': _rating,
          'comment': _commentController.text.trim(),
        },
      );

      if (!context.mounted) return;
      Navigator.of(context).pop();
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.tr('thanksFeedback'))),
      );
    } catch (_) {
      if (!context.mounted) return;
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.tr('failedSubmitRating'))),
      );
    }
  }
}

class _ProofData {
  final String receiverName;
  final String deliveryNotes;
  final String? photoUrl;
  const _ProofData({
    required this.receiverName,
    required this.deliveryNotes,
    this.photoUrl,
  });
}

class _DeliveryProofDialog extends StatefulWidget {
  const _DeliveryProofDialog();

  @override
  State<_DeliveryProofDialog> createState() => _DeliveryProofDialogState();
}

class _DeliveryProofDialogState extends State<_DeliveryProofDialog> {
  final _receiverController = TextEditingController();
  final _notesController = TextEditingController();
  final _photoController = TextEditingController();

  @override
  void dispose() {
    _receiverController.dispose();
    _notesController.dispose();
    _photoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(localizations.tr('proofOfDelivery')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _receiverController,
              decoration: InputDecoration(
                labelText: localizations.tr('receiverName'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: localizations.tr('deliveryNotes'),
                border: const OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _photoController,
              decoration: InputDecoration(
                labelText: localizations.tr('photoUrlOptional'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(localizations.tr('cancel')),
        ),
        ElevatedButton(
          onPressed: () {
            final receiver = _receiverController.text.trim();
            final notes = _notesController.text.trim();
            if (receiver.isEmpty || notes.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(localizations.tr('receiverAndNotesRequired'))),
              );
              return;
            }
            Navigator.of(context).pop(
              _ProofData(
                receiverName: receiver,
                deliveryNotes: notes,
                photoUrl: _photoController.text.trim().isEmpty ? null : _photoController.text.trim(),
              ),
            );
          },
          child: Text(localizations.tr('completeDelivery')),
        ),
      ],
    );
  }
}

class _IssueData {
  final String category;
  final String details;
  const _IssueData({required this.category, required this.details});
}

class _ReportIssueDialog extends StatefulWidget {
  const _ReportIssueDialog();

  @override
  State<_ReportIssueDialog> createState() => _ReportIssueDialogState();
}

class _ReportIssueDialogState extends State<_ReportIssueDialog> {
  final _detailsController = TextEditingController();
  String _category = 'Delay';

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(localizations.tr('reportShipmentIssue')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _category,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: localizations.tr('issueCategory'),
            ),
            items: [
              DropdownMenuItem(value: 'Delay', child: Text(localizations.tr('delay'))),
              DropdownMenuItem(value: 'Damaged goods', child: Text(localizations.tr('damagedGoods'))),
              DropdownMenuItem(value: 'Communication', child: Text(localizations.tr('communicationIssue'))),
              DropdownMenuItem(value: 'Payment', child: Text(localizations.tr('paymentIssue'))),
              DropdownMenuItem(value: 'Other', child: Text(localizations.tr('otherIssue'))),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _category = value);
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _detailsController,
            decoration: InputDecoration(
              labelText: localizations.tr('issueDetailsPrompt'),
              border: const OutlineInputBorder(),
            ),
            minLines: 3,
            maxLines: 5,
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations.tr('cancel'))),
        ElevatedButton(
          onPressed: () {
            final details = _detailsController.text.trim();
            if (details.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(localizations.tr('pleaseAddIssueDetails'))),
              );
              return;
            }
            Navigator.of(context).pop(_IssueData(category: _category, details: details));
          },
          child: Text(localizations.tr('submit')),
        ),
      ],
    );
  }
}
