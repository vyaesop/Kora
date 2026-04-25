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
import 'package:kora/utils/load_categories.dart';

class TrackLoadsScreen extends StatefulWidget {
  final bool showBack;

  const TrackLoadsScreen({super.key, this.showBack = true});

  @override
  State<TrackLoadsScreen> createState() => _TrackLoadsScreenState();
}

class _TrackLoadsScreenState extends State<TrackLoadsScreen> {
  static const int _pageSize = 12;

  final BackendAuthService _authService = BackendAuthService();
  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  String? _userId;
  int _nextOffset = 0;
  List<Map<String, dynamic>> _loads = const [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _loading ||
        _loadingMore ||
        !_hasMore) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      _loadMore();
    }
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final page = await _fetchPage(offset: 0, forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _loads = page.items;
        _hasMore = page.hasMore;
        _nextOffset = page.nextOffset;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = ErrorHandler.getMessage(error);
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;

    setState(() => _loadingMore = true);
    try {
      final page = await _fetchPage(offset: _nextOffset);
      if (!mounted) return;
      setState(() {
        _loads = [..._loads, ...page.items];
        _hasMore = page.hasMore;
        _nextOffset = page.nextOffset;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _error = ErrorHandler.getMessage(error);
      });
    }
  }

  Future<_PagedLoads> _fetchPage({
    required int offset,
    bool forceRefresh = false,
  }) async {
    final userId = _userId ?? await _authService.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      throw Exception('Not signed in');
    }
    _userId = userId;

    final data = await BackendHttp.request(
      path: '/api/users/$userId/threads?limit=$_pageSize&offset=$offset',
      cacheTtl: const Duration(seconds: 20),
      forceRefresh: forceRefresh,
    );

    final items = ((data['threads'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final pagination =
        data['pagination'] as Map<String, dynamic>? ??
        const <String, dynamic>{};

    return _PagedLoads(
      items: items,
      hasMore: pagination['hasMore'] == true,
      nextOffset:
          (pagination['nextOffset'] as num?)?.toInt() ??
          (offset + items.length),
    );
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tr('loadDeleted'))),
      );
      await _load(forceRefresh: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ErrorHandler.getMessage(error))));
    }
  }

  ThreadMessage _toThreadMessage(Map<String, dynamic> load) =>
      ThreadMessage.fromApiMap(load);

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
    if (raw == null || raw.isEmpty) return 'Just now';
    final date = DateTime.tryParse(raw);
    if (date == null) return 'Just now';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeCount = _loads.where((load) {
      final status = (load['deliveryStatus'] ?? 'pending_bids').toString();
      return status != 'delivered' && status != 'cancelled';
    }).length;
    final deliveredCount = _loads.length - activeCount;

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
            onPressed: () => _load(forceRefresh: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: const [
                _LoadingPanel(height: 176),
                SizedBox(height: 12),
                _LoadingPanel(height: 188),
                SizedBox(height: 12),
                _LoadingPanel(height: 188),
              ],
            )
          : _error != null
          ? _LoadsStateView(
              icon: Icons.inventory_2_outlined,
              title: 'Could not load your shipments',
              subtitle: _error!,
              primaryLabel: localizations.tr('retry'),
              onPrimaryTap: () => _load(forceRefresh: true),
            )
          : RefreshIndicator(
              onRefresh: () => _load(forceRefresh: true),
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: _loads.length + (_loadingMore ? 2 : 1),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
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
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
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
                                    _HeroStat(
                                      label: 'Total',
                                      value: '${_loads.length}',
                                    ),
                                    _HeroStat(
                                      label: 'Active',
                                      value: '$activeCount',
                                    ),
                                    _HeroStat(
                                      label: 'Delivered',
                                      value: '$deliveredCount',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (_loads.isEmpty) ...[
                            const SizedBox(height: 16),
                            _LoadsStateView(
                              icon: Icons.local_shipping_outlined,
                              title: localizations.tr('noLoadsPosted'),
                              subtitle:
                                  'Once you post a load, it will appear here with route, status, and bid progress.',
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  final itemIndex = index - 1;
                  if (itemIndex >= _loads.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final load = _loads[itemIndex];
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
                        if (threadMessage.type.isNotEmpty ||
                            threadMessage.category.isNotEmpty)
                          displayLoadType(
                            category: threadMessage.category,
                            subtype: threadMessage.type,
                          ),
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
                },
              ),
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

class _PagedLoads {
  final List<Map<String, dynamic>> items;
  final bool hasMore;
  final int nextOffset;

  const _PagedLoads({
    required this.items,
    required this.hasMore,
    required this.nextOffset,
  });
}
