import 'package:flutter/material.dart';
import 'package:kora/app_localizations.dart';
import 'package:kora/model/thread_message.dart';
import 'package:kora/screens/comment_screen.dart';
import 'package:kora/utils/app_theme.dart';
import 'package:kora/utils/backend_http.dart';
import 'package:kora/utils/error_handler.dart';
import 'package:kora/utils/firestore_service.dart';
import 'package:kora/utils/formatters.dart';
import 'package:kora/utils/load_categories.dart';

class MyBidsScreen extends StatefulWidget {
  const MyBidsScreen({super.key});

  @override
  State<MyBidsScreen> createState() => _MyBidsScreenState();
}

class _MyBidsScreenState extends State<MyBidsScreen> {
  static const int _pageSize = 12;

  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _nextOffset = 0;
  List<Map<String, dynamic>> _bids = const [];

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
        _bids = page.items;
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
        _bids = [..._bids, ...page.items];
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

  Future<_PagedBids> _fetchPage({
    required int offset,
    bool forceRefresh = false,
  }) async {
    final data = await BackendHttp.request(
      path: '/api/bids/me?limit=$_pageSize&offset=$offset',
      cacheTtl: const Duration(seconds: 20),
      forceRefresh: forceRefresh,
    );
    final items = ((data['bids'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final pagination =
        data['pagination'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    return _PagedBids(
      items: items,
      hasMore: pagination['hasMore'] == true,
      nextOffset:
          (pagination['nextOffset'] as num?)?.toInt() ??
          (offset + items.length),
    );
  }

  Future<void> _deleteBid(String bidId, String threadId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).tr('withdrawBid')),
        content: Text(
          AppLocalizations.of(context).tr('withdrawBidConfirmation'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context).tr('withdraw')),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await FirestoreService().deleteBid(threadId: threadId, bidId: bidId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).tr('bidWithdrawn')),
        ),
      );
      await _load(forceRefresh: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ErrorHandler.getMessage(error))));
    }
  }

  ThreadMessage _threadToMessage(Map<String, dynamic> thread) =>
      ThreadMessage.fromApiMap(thread);

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      case 'completed':
        return 'Completed';
      case 'withdrawn':
        return 'Withdrawn';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'completed':
        return const Color(0xFF16A34A);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFFDC2626);
      case 'withdrawn':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF2563EB);
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
    final pendingCount = _bids.where((bid) {
      return (bid['status'] ?? 'pending').toString().toLowerCase() == 'pending';
    }).length;
    final wonCount = _bids.where((bid) {
      final status = (bid['status'] ?? 'pending').toString().toLowerCase();
      return status == 'accepted' || status == 'completed';
    }).length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(localizations.tr('myBids')),
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
                _LoadingPanel(height: 160),
                SizedBox(height: 12),
                _LoadingPanel(height: 160),
              ],
            )
          : _error != null
          ? _BidsStateView(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load your bids',
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
                itemCount: _bids.length + (_loadingMore ? 2 : 1),
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
                                  localizations.tr('myBids'),
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Track every offer, keep pending bids in view, and reopen the right load without hunting through the feed.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white70,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _HeroStat(
                                      label: 'Total bids',
                                      value: '${_bids.length}',
                                    ),
                                    _HeroStat(
                                      label: 'Pending',
                                      value: '$pendingCount',
                                    ),
                                    _HeroStat(label: 'Won', value: '$wonCount'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (_bids.isEmpty) ...[
                            const SizedBox(height: 16),
                            _BidsStateView(
                              icon: Icons.local_offer_outlined,
                              title: localizations.tr('noBidsPlacedYet'),
                              subtitle:
                                  'Your bids will show up here with status, route details, and quick actions.',
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  final itemIndex = index - 1;
                  if (itemIndex >= _bids.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final bid = _bids[itemIndex];
                  final bidId = (bid['id'] ?? '').toString();
                  final thread =
                      (bid['load'] as Map<String, dynamic>? ??
                      const <String, dynamic>{});
                  final amount = (bid['amount'] as num?)?.toDouble() ?? 0.0;
                  final currency = (bid['currency'] ?? 'Birr').toString();
                  final status = (bid['status'] ?? 'pending').toString();
                  final threadId = (thread['id'] ?? '').toString();
                  final threadMessage = _threadToMessage(thread);
                  final weight = formatWeight(
                    threadMessage.weight,
                    threadMessage.weightUnit,
                  );

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BidCard(
                      title: threadMessage.message.trim().isEmpty
                          ? '${threadMessage.start} -> ${threadMessage.end}'
                          : threadMessage.message,
                      start: threadMessage.start,
                      end: threadMessage.end,
                      amount: formatPrice(amount, currency),
                      statusLabel: _statusLabel(status),
                      statusColor: _statusColor(status),
                      meta: [
                        if (threadMessage.type.isNotEmpty ||
                            threadMessage.category.isNotEmpty)
                          displayLoadType(
                            category: threadMessage.category,
                            subtype: threadMessage.type,
                          ),
                        if (threadMessage.packaging.isNotEmpty)
                          threadMessage.packaging,
                        if (threadMessage.weight > 0) weight,
                        'Updated ${_relativeTime(bid['createdAt']?.toString())}',
                      ],
                      onOpen: threadId.isEmpty
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CommentScreen(
                                    threadId: threadId,
                                    message: threadMessage,
                                  ),
                                ),
                              );
                            },
                      onWithdraw: status.toLowerCase() == 'pending'
                          ? () => _deleteBid(bidId, threadId)
                          : null,
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _BidCard extends StatelessWidget {
  final String title;
  final String start;
  final String end;
  final String amount;
  final String statusLabel;
  final Color statusColor;
  final List<String> meta;
  final VoidCallback? onOpen;
  final VoidCallback? onWithdraw;

  const _BidCard({
    required this.title,
    required this.start,
    required this.end,
    required this.amount,
    required this.statusLabel,
    required this.statusColor,
    required this.meta,
    this.onOpen,
    this.onWithdraw,
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
                    const SizedBox(height: 8),
                    Text(
                      '$start -> $end',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? AppPalette.darkTextSoft
                            : Colors.grey.shade700,
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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha((0.12 * 255).round()),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.payments_outlined, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your offer',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isDark
                              ? AppPalette.darkTextSoft
                              : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        amount,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: meta.map((item) => _MetaPill(label: item)).toList(),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open load'),
                ),
              ),
              if (onWithdraw != null) ...[
                const SizedBox(width: 10),
                TextButton.icon(
                  onPressed: onWithdraw,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Withdraw'),
                ),
              ],
            ],
          ),
        ],
      ),
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

class _BidsStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? primaryLabel;
  final VoidCallback? onPrimaryTap;

  const _BidsStateView({
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

class _PagedBids {
  final List<Map<String, dynamic>> items;
  final bool hasMore;
  final int nextOffset;

  const _PagedBids({
    required this.items,
    required this.hasMore,
    required this.nextOffset,
  });
}
