import 'package:flutter/material.dart';

import 'package:kora/app_localizations.dart';
import 'package:kora/model/thread_message.dart';
import 'package:kora/screens/comment_screen.dart';
import 'package:kora/utils/app_theme.dart';
import 'package:kora/utils/backend_auth_service.dart';
import 'package:kora/utils/backend_http.dart';
import 'package:kora/utils/delivery_status.dart';
import 'package:kora/utils/error_handler.dart';
import 'package:kora/utils/formatters.dart';

class TrackLoadsScreen extends StatefulWidget {
  final bool showBack;

  const TrackLoadsScreen({super.key, this.showBack = true});

  @override
  State<TrackLoadsScreen> createState() => _TrackLoadsScreenState();
}

class _TrackLoadsScreenState extends State<TrackLoadsScreen> {
  final BackendAuthService _authService = BackendAuthService();
  late Future<List<Map<String, dynamic>>> _loadsFuture;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadsFuture = _fetchMyLoads();
  }

  Future<void> _reload({bool forceRefresh = false}) async {
    final future = _fetchMyLoads(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() => _loadsFuture = future);
    }
    await future;
  }

  Future<List<Map<String, dynamic>>> _fetchMyLoads({
    bool forceRefresh = false,
  }) async {
    final userId = _userId ?? await _authService.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      throw Exception('Not signed in');
    }
    _userId = userId;

    final data = await BackendHttp.request(
      path: '/api/users/$userId/threads',
      cacheTtl: const Duration(seconds: 20),
      forceRefresh: forceRefresh,
    );

    return (data['threads'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<void> _deleteLoad(String loadId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).tr('deleteLoad')),
        content: Text(
          AppLocalizations.of(context).tr('deleteLoadConfirmation'),
        ),
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

    if (confirmed != true) {
      return;
    }

    try {
      await BackendHttp.request(
        path: '/api/threads/$loadId',
        method: 'DELETE',
        forceRefresh: true,
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tr('loadDeleted'))),
      );
      await _reload(forceRefresh: true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context).tr('error')}: ${ErrorHandler.getMessage(e)}',
          ),
        ),
      );
    }
  }

  ThreadMessage _toThreadMessage(Map<String, dynamic> load) {
    final owner = load['owner'] as Map<String, dynamic>? ?? const {};
    final createdRaw = load['createdAt']?.toString();
    final createdAt = createdRaw == null
        ? DateTime.now()
        : DateTime.tryParse(createdRaw) ?? DateTime.now();

    return ThreadMessage(
      id: (load['id'] ?? '').toString(),
      docId: (load['id'] ?? '').toString(),
      senderName: (owner['name'] ?? '').toString(),
      senderProfileImageUrl: (owner['profileImageUrl'] ?? '').toString(),
      ownerId: (load['ownerId'] ?? owner['id'] ?? '').toString(),
      message: (load['message'] ?? '').toString(),
      timestamp: createdAt,
      likes: const [],
      comments: const [],
      weight: (load['weight'] as num?)?.toDouble() ?? 0.0,
      type: (load['type'] ?? '').toString(),
      start: (load['start'] ?? '').toString(),
      end: (load['end'] ?? '').toString(),
      packaging: (load['packaging'] ?? '').toString(),
      weightUnit: (load['weightUnit'] ?? 'kg').toString(),
      startLat: (load['startLat'] as num?)?.toDouble() ?? 0.0,
      startLng: (load['startLng'] as num?)?.toDouble() ?? 0.0,
      endLat: (load['endLat'] as num?)?.toDouble() ?? 0.0,
      endLng: (load['endLng'] as num?)?.toDouble() ?? 0.0,
      deliveryStatus: (load['deliveryStatus'] ?? 'pending_bids').toString(),
    );
  }

  Color _statusColor(String rawStatus) {
    switch (rawStatus.toLowerCase()) {
      case 'pending_bids':
        return const Color(0xFFF59E0B);
      case 'accepted':
      case 'driving_to_location':
      case 'picked_up':
      case 'on_the_road':
        return const Color(0xFF0EA5E9);
      case 'delivered':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _relativeTime(String? raw) {
    if (raw == null || raw.isEmpty) {
      return 'Just now';
    }

    final date = DateTime.tryParse(raw);
    if (date == null) {
      return 'Just now';
    }

    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) {
      return 'Just now';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: widget.showBack
            ? IconButton(
                tooltip: localizations.tr('back'),
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(localizations.tr('myLoads')),
        actions: [
          IconButton(
            tooltip: localizations.tr('refresh'),
            onPressed: () => _reload(forceRefresh: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: const [
                _LoadingPanel(height: 176),
                SizedBox(height: 12),
                _LoadingPanel(height: 188),
                SizedBox(height: 12),
                _LoadingPanel(height: 188),
              ],
            );
          }

          if (snapshot.hasError) {
            return _LoadsStateView(
              icon: Icons.inventory_2_outlined,
              title: 'Could not load your shipments',
              subtitle: ErrorHandler.getMessage(snapshot.error!),
              primaryLabel: localizations.tr('retry'),
              onPrimaryTap: () => _reload(forceRefresh: true),
            );
          }

          final loads = snapshot.data ?? const <Map<String, dynamic>>[];
          final activeCount = loads.where((load) {
            final status = (load['deliveryStatus'] ?? 'pending_bids')
                .toString();
            return status != 'delivered' && status != 'cancelled';
          }).length;
          final deliveredCount = loads.length - activeCount;

          return RefreshIndicator(
            onRefresh: () => _reload(forceRefresh: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Keep posted shipments organized with clear route cards, bid visibility, and one-tap access to the full thread.',
                        style: theme.textTheme.bodyMedium?.copyWith(
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
                          _HeroStat(
                            label: 'Delivered',
                            value: '$deliveredCount',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (loads.isEmpty)
                  _LoadsStateView(
                    icon: Icons.local_shipping_outlined,
                    title: localizations.tr('noLoadsPosted'),
                    subtitle:
                        'Once you post a load, it will appear here with route, status, and bid progress.',
                  )
                else
                  ...loads.map((load) {
                    final bidCount =
                        (load['bids'] as List<dynamic>?)?.length ??
                        ((load['bids_count'] as num?)?.toInt() ?? 0);
                    final threadMessage = _toThreadMessage(load);
                    final rawStatus = (load['deliveryStatus'] ?? 'pending_bids')
                        .toString();
                    final status = deliveryStatusLabel(rawStatus);
                    final statusColor = _statusColor(rawStatus);
                    final loadId = (load['id'] ?? '').toString();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LoadCard(
                        title: threadMessage.message.trim().isEmpty
                            ? '${threadMessage.start} -> ${threadMessage.end}'
                            : threadMessage.message,
                        start: threadMessage.start,
                        end: threadMessage.end,
                        statusLabel: status,
                        statusColor: statusColor,
                        weight: threadMessage.weight > 0
                            ? formatWeight(
                                threadMessage.weight,
                                threadMessage.weightUnit,
                              )
                            : 'Weight pending',
                        bidCount: bidCount,
                        updatedAt:
                            'Updated ${_relativeTime(load['updatedAt']?.toString())}',
                        meta: [
                          if (threadMessage.type.isNotEmpty) threadMessage.type,
                          if (threadMessage.packaging.isNotEmpty)
                            threadMessage.packaging,
                        ],
                        onOpen: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CommentScreen(
                                threadId: loadId,
                                message: threadMessage,
                              ),
                            ),
                          );
                        },
                        onDelete: rawStatus == 'pending_bids'
                            ? () => _deleteLoad(loadId)
                            : null,
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LoadCard extends StatelessWidget {
  final String title;
  final String start;
  final String end;
  final String statusLabel;
  final Color statusColor;
  final String weight;
  final int bidCount;
  final String updatedAt;
  final List<String> meta;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  const _LoadCard({
    required this.title,
    required this.start,
    required this.end,
    required this.statusLabel,
    required this.statusColor,
    required this.weight,
    required this.bidCount,
    required this.updatedAt,
    required this.meta,
    required this.onOpen,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      updatedAt,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppPalette.darkTextSoft
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha((0.14 * 255).round()),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  statusLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? AppPalette.darkSurfaceRaised
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _RouteStop(
                    label: 'Departure',
                    value: start,
                    icon: Icons.trip_origin,
                    color: statusColor,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.east_rounded,
                    color: isDark
                        ? AppPalette.darkTextSoft
                        : Colors.blueGrey.shade400,
                  ),
                ),
                Expanded(
                  child: _RouteStop(
                    label: 'Destination',
                    value: end,
                    icon: Icons.location_on_outlined,
                    color: const Color(0xFFC28C5A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaPill(label: weight),
              _MetaPill(label: '$bidCount bids'),
              ...meta.map((item) => _MetaPill(label: item)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open thread'),
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 10),
                TextButton.icon(
                  onPressed: onDelete,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteStop extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _RouteStop({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.blueGrey.shade500,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeroStat({required this.label, required this.value});

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
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
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
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _LoadsStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? primaryLabel;
  final VoidCallback? onPrimaryTap;

  const _LoadsStateView({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.primaryLabel,
    this.onPrimaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppPalette.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? AppPalette.darkOutline : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppPalette.darkSurfaceRaised
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppPalette.darkTextSoft
                      : Colors.grey.shade700,
                  height: 1.45,
                ),
              ),
              if (primaryLabel != null && onPrimaryTap != null) ...[
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: onPrimaryTap,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(primaryLabel!),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  final double height;

  const _LoadingPanel({required this.height});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppPalette.darkOutline : const Color(0xFFE5E7EB),
        ),
      ),
    );
  }
}
