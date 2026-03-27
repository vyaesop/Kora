import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kora/app_localizations.dart';
import 'package:kora/utils/app_theme.dart';
import 'package:kora/utils/delivery_status.dart';
import 'package:kora/utils/firestore_service.dart';

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

  @override
  void initState() {
    super.initState();
    _flushQueuedUpdates();
  }

  String normalizeStatus(String s) {
    final key = s.toLowerCase();
    if (key == 'accepted') return 'accepted';
    if (key == 'driving' || key == 'driving_to_location') {
      return 'driving_to_location';
    }
    if (key == 'picked' || key == 'picked_up') {
      return 'picked_up';
    }
    if (key == 'on_the_road' || key == 'ontheroad' || key == 'onroad') {
      return 'on_the_road';
    }
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
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localizations.tr('statusUpdatedTo')} ${deliveryStatusLabel(status)}.',
            ),
          ),
        );
      }
      await _flushQueuedUpdates();
    } catch (_) {
      await _queueStatusUpdate(status);
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.tr('offlineStatusQueued'))),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final normalized = normalizeStatus(widget.currentStatus);
    final baseIndex = normalized == 'accepted' ? -1 : _statuses.indexOf(normalized);
    final currentIndex = baseIndex < 0 ? 0 : baseIndex;
    final nextIndex = normalized == 'accepted' ? 0 : baseIndex + 1;
    final nextStatus =
        nextIndex >= 0 && nextIndex < _statuses.length ? _statuses[nextIndex] : null;
    final progress = normalized == 'accepted'
        ? 0.0
        : (currentIndex + 1) / _statuses.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppPalette.darkOutline : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Driver delivery updates',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${localizations.tr('currentStatusLabel')}: ${deliveryStatusLabel(widget.currentStatus)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppPalette.darkTextSoft : Colors.black54,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor:
                  isDark ? AppPalette.darkSurfaceRaised : Colors.grey.shade200,
              color: AppPalette.accent,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _statuses.asMap().entries.map((entry) {
              final index = entry.key;
              final status = entry.value;
              final isActive = index <= currentIndex;
              final isNext = nextStatus == status;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? (isDark
                          ? AppPalette.accent.withAlpha((0.16 * 255).round())
                          : Colors.blue.shade50)
                      : (isDark
                          ? AppPalette.darkSurfaceRaised
                          : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isNext
                        ? AppPalette.accent
                        : (isDark
                            ? AppPalette.darkOutline
                            : Colors.grey.shade200),
                  ),
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
          if (nextStatus != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppPalette.darkSurfaceRaised : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next milestone',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    deliveryStatusLabel(nextStatus),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _updating ? null : () => _setStatus(nextStatus),
                      icon: _updating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        _updating
                            ? localizations.tr('refreshing')
                            : 'Update to ${deliveryStatusLabel(nextStatus)}',
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'All delivery stages are complete.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? AppPalette.darkTextSoft : Colors.black54,
              ),
            ),
        ],
      ),
    );
  }
}
