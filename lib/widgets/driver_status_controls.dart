import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Kora/utils/firestore_service.dart';
import 'package:Kora/utils/delivery_status.dart';

class DriverStatusControls extends StatefulWidget {
  final String threadId;
  final String currentStatus;
  const DriverStatusControls({
    super.key,
    required this.threadId,
    required this.currentStatus,
  });

  @override
  State<DriverStatusControls> createState() => _DriverStatusControlsState();
}

class _DriverStatusControlsState extends State<DriverStatusControls> {
  static const String _queueKey = 'queued_driver_status_updates';
  bool _updating = false;

  List<String> get _statuses => const [
        'driving_to_location',
        'picked_up',
        'on_the_road',
        'delivered',
      ];

  List<String> get _labels => const [
        'Driving to Location',
        'Picked Up',
        'On the Road',
        'Delivered',
      ];

  @override
  void initState() {
    super.initState();
    _flushQueuedUpdates();
  }

  String normalizeStatus(String s) {
    final key = s.toLowerCase();
    if (key == 'accepted') return 'accepted';
    if (key == 'driving' || key == 'driving_to_location')
      return 'driving_to_location';
    if (key == 'picked' || key == 'picked_up') return 'picked_up';
    if (key == 'on_the_road' || key == 'ontheroad' || key == 'onroad')
      return 'on_the_road';
    if (key == 'delivered' || key == 'completed') return 'delivered';
    return s;
  }

  Future<void> _queueStatusUpdate(String status) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString(_queueKey);
    final List<dynamic> parsed =
        current == null ? [] : jsonDecode(current) as List<dynamic>;
    parsed.add({
      'threadId': widget.threadId,
      'status': status,
      'queuedAt': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_queueKey, jsonEncode(parsed));
  }

  Future<void> _flushQueuedUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString(_queueKey);
    if (current == null || current.isEmpty) return;

    final List<dynamic> entries = jsonDecode(current) as List<dynamic>;
    final List<dynamic> remaining = [];

    for (final raw in entries) {
      try {
        final entry = raw as Map<String, dynamic>;
        final threadId = (entry['threadId'] ?? '').toString();
        final status = (entry['status'] ?? '').toString();
        if (threadId.isEmpty || status.isEmpty) continue;

        await FirestoreService().updateDriverDeliveryStatus(
          threadId: threadId,
          nextStatus: status,
        );
      } catch (_) {
        remaining.add(raw);
      }
    }

    if (remaining.isEmpty) {
      await prefs.remove(_queueKey);
    } else {
      await prefs.setString(_queueKey, jsonEncode(remaining));
    }
  }

  Future<void> _setStatus(String status) async {
    if (_updating) return;
    setState(() => _updating = true);

    try {
      await FirestoreService().updateDriverDeliveryStatus(
        threadId: widget.threadId,
        nextStatus: status,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Status updated to ${deliveryStatusLabel(status)}.')),
        );
      }
      await _flushQueuedUpdates();
    } catch (e) {
      await _queueStatusUpdate(status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'You appear offline. Status queued and will sync automatically.')),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeStatus(widget.currentStatus);

    // Accepted means first actionable state is "driving_to_location".
    final baseIndex =
        normalized == 'accepted' ? -1 : _statuses.indexOf(normalized);
    int currentIndex = baseIndex;
    final bool unknownStatus = currentIndex < 0;

    if (unknownStatus && normalized != 'accepted') {
      // Log unexpected status for debugging
      debugPrint(
          'Warning: unknown delivery status "${widget.currentStatus}" for thread ${widget.threadId}');
      // Clamp progress to 0 so indicator doesn't break
      currentIndex = 0;
    }

    final progress =
        normalized == 'accepted' ? 0.0 : (currentIndex + 1) / _statuses.length;

    return Column(
      children: [
        LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          minHeight: 8,
          backgroundColor: Colors.grey[300],
          color: Colors.blue,
        ),
        const SizedBox(height: 8),
        Text(
          unknownStatus
              ? 'Current Status: ${deliveryStatusLabel(widget.currentStatus)}'
              : (normalized == 'accepted'
                  ? 'Current Status: ${deliveryStatusLabel('accepted')}'
                  : 'Current Status: ${_labels[currentIndex]}'),
          style:
              const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        ...List.generate(_statuses.length, (i) {
          final canTap =
              normalized == 'accepted' ? i == 0 : i == (baseIndex + 1);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: ElevatedButton(
              onPressed:
                  _updating || !canTap ? null : () => _setStatus(_statuses[i]),
              child: _updating && canTap
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_labels[i]),
            ),
          );
        }),
      ],
    );
  }
}
