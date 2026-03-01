import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Kora/screens/track_driver_map_screen.dart';
import 'package:Kora/screens/shipment_chat_screen.dart';
import 'package:Kora/utils/backend_auth_service.dart';
import 'package:Kora/utils/backend_config.dart';

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
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue[50],
      child: Wrap(
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
              label: const Text('Track Driver'),
            ),
          ElevatedButton.icon(
            onPressed: () {
              _launchMessage(context, isShipper ? carrierId : ownerId);
            },
            icon: const Icon(Icons.message),
            label: Text(isShipper ? 'Message Carrier' : 'Message Shipper'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShipmentChatScreen(
                    threadId: threadId,
                    peerId: isShipper ? carrierId : ownerId,
                    peerLabel: isShipper ? 'Carrier' : 'Shipper',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('In-App Chat'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              _launchCall(context, isShipper ? driverId : ownerId);
            },
            icon: const Icon(Icons.call),
            label: Text(isShipper ? 'Call Driver' : 'Call Shipper'),
          ),
          if (isShipper)
            ElevatedButton.icon(
              onPressed: _canMarkDelivered(deliveryStatus)
                  ? () => _completeDeliveryWithProof(context)
                  : null,
              icon: const Icon(Icons.task_alt),
              label: const Text('Mark Delivered'),
            ),
          OutlinedButton.icon(
            onPressed: () => _reportIssue(context),
            icon: const Icon(Icons.report_problem_outlined),
            label: const Text('Report Issue'),
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot complete delivery: missing accepted bid reference.')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to complete delivery: $e')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Issue reported. Support can now review this load.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to report issue: $e')),
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
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number available for messaging.')),
      );
      return;
    }
    final uri = Uri(scheme: 'sms', path: phone);
    if (!await launchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the messaging app.')),
      );
    }
  }

  Future<void> _launchCall(BuildContext context, String userId) async {
    final phone = await _getPhoneNumber(userId);
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number available for calling.')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the phone dialer.')),
      );
    }
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
    return AlertDialog(
      title: const Text('Rate the Driver'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Please rate your experience with the driver.'),
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
            decoration: const InputDecoration(
              labelText: 'Optional feedback',
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
          child: const Text('Submit'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
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

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks for your feedback!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit rating. Please try again.')),
        );
      }
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
    return AlertDialog(
      title: const Text('Proof of Delivery'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _receiverController,
              decoration: const InputDecoration(
                labelText: 'Receiver name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Delivery notes',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _photoController,
              decoration: const InputDecoration(
                labelText: 'Photo URL (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final receiver = _receiverController.text.trim();
            final notes = _notesController.text.trim();
            if (receiver.isEmpty || notes.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Receiver name and delivery notes are required.')),
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
          child: const Text('Complete Delivery'),
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
    return AlertDialog(
      title: const Text('Report Shipment Issue'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Issue category',
            ),
            items: const [
              DropdownMenuItem(value: 'Delay', child: Text('Delay')),
              DropdownMenuItem(value: 'Damaged goods', child: Text('Damaged goods')),
              DropdownMenuItem(value: 'Communication', child: Text('Communication')),
              DropdownMenuItem(value: 'Payment', child: Text('Payment')),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _category = value);
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _detailsController,
            decoration: const InputDecoration(
              labelText: 'What happened?',
              border: OutlineInputBorder(),
            ),
            minLines: 3,
            maxLines: 5,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final details = _detailsController.text.trim();
            if (details.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please add issue details.')),
              );
              return;
            }
            Navigator.of(context).pop(_IssueData(category: _category, details: details));
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}