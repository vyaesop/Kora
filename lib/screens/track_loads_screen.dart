import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:kora/app_localizations.dart';
import 'package:kora/utils/app_theme.dart';
import 'package:kora/utils/backend_auth_service.dart';
import 'package:kora/utils/backend_config.dart';
import 'package:kora/utils/delivery_status.dart';
import 'package:kora/utils/error_handler.dart';

class TrackLoadsScreen extends StatefulWidget {
  final bool showBack;

  const TrackLoadsScreen({super.key, this.showBack = true});

  @override
  State<TrackLoadsScreen> createState() => _TrackLoadsScreenState();
}

class _TrackLoadsScreenState extends State<TrackLoadsScreen> {
  int _reloadToken = 0;
  final BackendAuthService _authService = BackendAuthService();

  void _retry() {
    setState(() => _reloadToken++);
  }

  Future<List<Map<String, dynamic>>> _fetchMyLoads() async {
    final token = await _authService.getToken();
    final userId = await _authService.getCurrentUserId();
    if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
      throw Exception('Not signed in');
    }

    final uri = Uri.parse('${BackendConfig.baseUrl}/api/threads?limit=100');
    final client = HttpClient();
    try {
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final res = await req.close();
      final raw = await utf8.decoder.bind(res).join();
      final data =
          raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw) as Map<String, dynamic>;
      if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] == false) {
        throw Exception((data['error'] ?? 'Request failed').toString());
      }

      return (data['threads'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .where((thread) => (thread['ownerId'] ?? '').toString() == userId)
          .toList();
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _deleteLoad(String loadId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).tr('deleteLoad')),
        content: Text(AppLocalizations.of(context).tr('deleteLoadConfirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context).tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = await _authService.getToken();
      if (token == null) throw Exception('Not signed in');

      final uri = Uri.parse('${BackendConfig.baseUrl}/api/threads/$loadId');
      final client = HttpClient();
      final req = await client.openUrl('DELETE', uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final res = await req.close();

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Failed to delete load');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tr('loadDeleted'))),
      );
      _retry();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context).tr('error')}: ${ErrorHandler.getMessage(e)}',
          ),
        ),
      );
    }
  }

  Color _statusColor(String rawStatus) {
    switch (rawStatus.toLowerCase()) {
      case 'pending_bids':
        return Colors.orange;
      case 'accepted':
      case 'driving_to_location':
      case 'picked_up':
      case 'on_the_road':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: widget.showBack
            ? IconButton(
                tooltip: localizations.tr('back'),
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(localizations.tr('myLoads')),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        key: ValueKey(_reloadToken),
        future: _fetchMyLoads(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    Text(
                      ErrorHandler.getMessage(snapshot.error!),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: Text(localizations.tr('retry')),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final loads = snapshot.data ?? const <Map<String, dynamic>>[];
          if (loads.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(localizations.tr('noLoadsPosted')),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: Text(localizations.tr('refresh')),
                    ),
                  ],
                ),
              ),
            );
          }

          final activeCount = loads
              .where((load) => (load['deliveryStatus'] ?? '').toString() != 'delivered')
              .length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: isDark
                      ? AppPalette.heroGradientDark
                      : AppPalette.heroGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My loads',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Keep an eye on active shipments, bid activity, and delivery progress from one screen.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _HeroStat(label: 'Total', value: '${loads.length}'),
                        _HeroStat(label: 'Active', value: '$activeCount'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...loads.map((load) {
                final bidCount = (load['bids'] as List<dynamic>?)?.length ??
                    ((load['bids_count'] as num?)?.toInt() ?? 0);
                final title =
                    (load['description'] ?? load['message'] ?? '').toString().trim();
                final start = (load['start'] ?? load['startCity'] ?? 'Unknown origin')
                    .toString();
                final end =
                    (load['end'] ?? load['endCity'] ?? 'Unknown destination')
                        .toString();
                final rawStatus =
                    (load['deliveryStatus'] ?? 'pending_bids').toString();
                final status = deliveryStatusLabel(rawStatus);
                final weight = (load['weight'] ?? '-').toString();
                final unit = (load['weightUnit'] ?? 'kg').toString();
                final loadId = (load['id'] ?? '').toString();
                final statusColor = _statusColor(rawStatus);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppPalette.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark
                            ? AppPalette.darkOutline
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title.isEmpty
                                        ? '${localizations.tr('loadIndex')} ${loads.indexOf(load) + 1}'
                                        : title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '$start -> $end',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: isDark
                                              ? AppPalette.darkTextSoft
                                              : Colors.black54,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusColor.withAlpha((0.12 * 255).round()),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _MetaPill(label: '$weight $unit'),
                            const SizedBox(width: 8),
                            _MetaPill(
                                label:
                                    '$bidCount ${localizations.tr('bidsCount')}'),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            if (rawStatus != 'delivered' && rawStatus != 'cancelled')
                              TextButton.icon(
                                onPressed: () => _deleteLoad(loadId),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red.shade400,
                                ),
                                icon: const Icon(Icons.delete_outline),
                                label: Text(localizations.tr('delete')),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeroStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String label;

  const _MetaPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkSurfaceRaised : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
