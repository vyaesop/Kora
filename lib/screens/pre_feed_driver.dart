import 'package:flutter/material.dart';
import 'package:kora/app_localizations.dart';
import 'package:kora/model/thread_message.dart';
import 'package:kora/model/user.dart';
import 'package:kora/screens/comment_screen.dart';
import 'package:kora/utils/app_theme.dart';
import 'package:kora/utils/backend_http.dart';
import 'package:kora/utils/delivery_status.dart';
import 'package:kora/utils/formatters.dart';
import 'package:kora/widgets/language_switcher.dart';

class PreFeedDriverScreen extends StatefulWidget {
  final UserModel user;
  final VoidCallback onContinueToFeed;
  final VoidCallback onOpenProfile;
  final void Function(int index) onSelectTab;
  final bool embedded;

  const PreFeedDriverScreen({
    super.key,
    required this.user,
    required this.onContinueToFeed,
    required this.onOpenProfile,
    required this.onSelectTab,
    this.embedded = false,
  });

  @override
  State<PreFeedDriverScreen> createState() => _PreFeedDriverScreenState();
}

class _PreFeedDriverScreenState extends State<PreFeedDriverScreen> {
  late Future<List<Map<String, dynamic>>> _suggestedLoadsFuture;
  late Future<List<Map<String, dynamic>>> _acceptedLoadsFuture;

  @override
  void initState() {
    super.initState();
    _suggestedLoadsFuture = _fetchSuggestedLoads();
    _acceptedLoadsFuture = _fetchAcceptedLoads();
  }

  Future<List<Map<String, dynamic>>> _fetchSuggestedLoads() async {
    final data = await BackendHttp.request(
      path: '/api/threads?limit=8',
      auth: false,
      cacheTtl: const Duration(seconds: 20),
    );
    return (data['threads'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where(
          (thread) => (thread['deliveryStatus'] ?? 'pending_bids').toString() ==
              'pending_bids',
        )
        .take(4)
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchAcceptedLoads() async {
    final data = await BackendHttp.request(
      path: '/api/bids/me',
      cacheTtl: const Duration(seconds: 20),
    );
    return (data['bids'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((bid) {
          final status = (bid['status'] ?? '').toString().toLowerCase();
          return status == 'accepted' || status == 'completed';
        })
        .map((bid) => bid['load'])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  ThreadMessage _threadMessageFromMap(Map<String, dynamic> row) {
    final owner = row['owner'] as Map<String, dynamic>? ?? const {};
    final createdRaw = row['createdAt']?.toString();
    final createdAt = createdRaw == null
        ? DateTime.now()
        : DateTime.tryParse(createdRaw) ?? DateTime.now();

    return ThreadMessage(
      id: (row['id'] ?? '').toString(),
      docId: (row['id'] ?? '').toString(),
      senderName: (owner['name'] ?? 'Load Owner').toString(),
      senderProfileImageUrl: (owner['profileImageUrl'] ?? '').toString(),
      message: (row['message'] ?? '').toString(),
      timestamp: createdAt,
      likes: const [],
      comments: const [],
      weight: (row['weight'] as num?)?.toDouble() ?? 0.0,
      type: (row['type'] ?? '').toString(),
      start: (row['start'] ?? '').toString(),
      end: (row['end'] ?? '').toString(),
      packaging: (row['packaging'] ?? '').toString(),
      weightUnit: (row['weightUnit'] ?? 'kg').toString(),
      startLat: (row['startLat'] as num?)?.toDouble() ?? 0.0,
      startLng: (row['startLng'] as num?)?.toDouble() ?? 0.0,
      endLat: (row['endLat'] as num?)?.toDouble() ?? 0.0,
      endLng: (row['endLng'] as num?)?.toDouble() ?? 0.0,
      deliveryStatus: row['deliveryStatus']?.toString(),
    );
  }

  void _openLoadDetails(BuildContext context, Map<String, dynamic> row) {
    final threadId = (row['id'] ?? '').toString();
    if (threadId.isEmpty) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommentScreen(
          threadId: threadId,
          message: _threadMessageFromMap(row),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final acceptedLoadsCount = widget.user.acceptedLoads?.length ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: widget.embedded
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              title: Text('${localizations.tr('welcome')}, ${widget.user.name}'),
              actions: const [
                Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: LanguageSwitcher(),
                ),
              ],
            ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.embedded) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${localizations.tr('welcome')}, ${widget.user.name}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const LanguageSwitcher(),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              _DashboardHero(
                eyebrow: localizations.tr('driverHubTitle'),
                title: 'Stay focused on the loads that need action.',
                subtitle:
                    'See your active work, jump into open opportunities, and keep your driver profile ready for new awards.',
                primaryLabel: localizations.tr('openFeed'),
                primaryIcon: Icons.rss_feed_rounded,
                onPrimaryTap: widget.onContinueToFeed,
                secondaryLabel: localizations.tr('myBids'),
                secondaryIcon: Icons.local_offer_outlined,
                onSecondaryTap: () => widget.onSelectTab(2),
                metrics: [
                  _HeroMetricData(
                    label: localizations.tr('activeJobs'),
                    value: acceptedLoadsCount.toString(),
                  ),
                  _HeroMetricData(
                    label: localizations.tr('suggestedLoads'),
                    value: '4',
                  ),
                  _HeroMetricData(
                    label: localizations.tr('profile'),
                    value: 'Ready',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SectionHeader(
                title: localizations.tr('quickActions'),
                subtitle:
                    'Use the shortcuts below to move straight to the next task.',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.route_outlined,
                      title: localizations.tr('openFeed'),
                      subtitle: 'Browse open loads without the extra search step.',
                      onTap: widget.onContinueToFeed,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.badge_outlined,
                      title: localizations.tr('profile'),
                      subtitle: 'Manage notifications and keep your account ready.',
                      onTap: widget.onOpenProfile,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _SectionHeader(
                title: localizations.tr('activeJobs'),
                subtitle: 'Loads already assigned to you.',
              ),
              const SizedBox(height: 10),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _acceptedLoadsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _LoadingList();
                  }
                  final docs = snapshot.data ?? const <Map<String, dynamic>>[];
                  if (docs.isEmpty) {
                    return _EmptyState(
                      title: localizations.tr('noActiveJobs'),
                      subtitle: localizations.tr('bidOnLoadsHint'),
                      buttonText: localizations.tr('openFeed'),
                      onTap: widget.onContinueToFeed,
                    );
                  }
                  return ListView.separated(
                    itemCount: docs.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final data = docs[index];
                      final start = (data['start'] ?? 'Unknown').toString();
                      final end = (data['end'] ?? 'Unknown').toString();
                      final unit = (data['weightUnit'] ?? 'kg').toString();
                      final weight = (data['weight'] as num?)?.toDouble();
                      final status =
                          (data['deliveryStatus'] ?? 'pending_bids').toString();
                      return _LoadCard(
                        title: '$start -> $end',
                        subtitle:
                            '${localizations.tr('weight')}: ${weight == null ? '-' : formatWeight(weight, unit)}',
                        trailing: _StatusPill(status: status),
                        footer:
                            '${localizations.tr('status')}: ${deliveryStatusLabel(status)}',
                        onTap: () => _openLoadDetails(context, data),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 22),
              _SectionHeader(
                title: localizations.tr('suggestedLoads'),
                subtitle: 'Fresh loads worth checking next.',
              ),
              const SizedBox(height: 10),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _suggestedLoadsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _LoadingList();
                  }
                  final docs = snapshot.data ?? const <Map<String, dynamic>>[];
                  if (docs.isEmpty) {
                    return _EmptyState(
                      title: localizations.tr('noSuggestionsYet'),
                      subtitle: localizations.tr('suggestedLoadsHint'),
                      buttonText: localizations.tr('openFeed'),
                      onTap: widget.onContinueToFeed,
                    );
                  }
                  return ListView.separated(
                    itemCount: docs.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final data = docs[index];
                      final start = (data['start'] ?? 'Unknown').toString();
                      final end = (data['end'] ?? 'Unknown').toString();
                      final unit = (data['weightUnit'] ?? 'kg').toString();
                      final weight = (data['weight'] as num?)?.toDouble();
                      return _LoadCard(
                        title: '$start -> $end',
                        subtitle:
                            '${localizations.tr('weight')}: ${weight == null ? '-' : formatWeight(weight, unit)}',
                        trailing: TextButton(
                          onPressed: () => _openLoadDetails(context, data),
                          child: const Text('Open'),
                        ),
                        footer: (data['type'] ?? localizations.tr('searchGeneral'))
                            .toString(),
                        onTap: () => _openLoadDetails(context, data),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.embedded
          ? null
          : BottomNavigationBar(
              currentIndex: 0,
              selectedItemColor:
                  isDark ? AppPalette.darkText : AppPalette.ink,
              unselectedItemColor:
                  isDark ? AppPalette.darkTextSoft : Colors.grey,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home_outlined),
                  label: localizations.tr('home'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.rss_feed),
                  label: localizations.tr('feed'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.local_offer_outlined),
                  label: localizations.tr('myBids'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.person_outline),
                  label: localizations.tr('profile'),
                ),
              ],
              onTap: (index) {
                if (index == 0) return;
                widget.onSelectTab(index);
              },
            ),
    );
  }
}

class _DashboardHero extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback onPrimaryTap;
  final String secondaryLabel;
  final IconData secondaryIcon;
  final VoidCallback onSecondaryTap;
  final List<_HeroMetricData> metrics;

  const _DashboardHero({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimaryTap,
    required this.secondaryLabel,
    required this.secondaryIcon,
    required this.onSecondaryTap,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppPalette.heroGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.14 * 255).round()),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: metrics
                .map(
                  (metric) => _MetricCard(
                    label: metric.label,
                    value: metric.value,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onPrimaryTap,
                  icon: Icon(primaryIcon),
                  label: Text(primaryLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppPalette.ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSecondaryTap,
                  icon: Icon(secondaryIcon),
                  label: Text(secondaryLabel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withAlpha((0.28 * 255).round()),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetricData {
  final String label;
  final String value;

  const _HeroMetricData({
    required this.label,
    required this.value,
  });
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withAlpha((0.16 * 255).round()),
        ),
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
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppPalette.ink,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? AppPalette.darkTextSoft : Colors.black54,
              ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppPalette.darkCard : AppPalette.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppPalette.darkOutline : const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(
                ((isDark ? 0.12 : 0.04) * 255).round(),
              ),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF0369A1)),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? AppPalette.darkTextSoft : Colors.black54,
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String footer;
  final Widget trailing;
  final VoidCallback? onTap;

  const _LoadCard({
    required this.title,
    required this.subtitle,
    required this.footer,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppPalette.darkCard : AppPalette.card,
          borderRadius: BorderRadius.circular(20),
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? AppPalette.darkTextSoft
                                  : Colors.black54,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                trailing,
              ],
            ),
            const SizedBox(height: 14),
            Text(
              footer,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppPalette.darkTextSoft
                        : const Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final normalized = status.toLowerCase();
    final color = normalized == 'pending_bids'
        ? Colors.orange
        : normalized == 'delivered'
            ? Colors.green
            : Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(((isDark ? 0.24 : 0.12) * 255).round()),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        deliveryStatusLabel(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: LinearProgressIndicator(minHeight: 2),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? buttonText;
  final VoidCallback? onTap;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    this.buttonText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkCard : AppPalette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppPalette.darkOutline : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppPalette.darkTextSoft : Colors.black54,
                ),
          ),
          if (buttonText != null && onTap != null) ...[
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onTap,
              child: Text(buttonText!),
            ),
          ],
        ],
      ),
    );
  }
}
