import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kora/app_localizations.dart';
import 'package:kora/model/user.dart';
import 'package:kora/utils/app_theme.dart';
import 'package:kora/utils/backend_auth_service.dart';
import 'package:kora/utils/backend_config.dart';
import 'package:kora/utils/delivery_status.dart';
import 'package:kora/widgets/language_switcher.dart';

class PreFeedCargoScreen extends StatefulWidget {
  final UserModel user;
  final VoidCallback onContinueToFeed;
  final VoidCallback onPostLoad;
  final VoidCallback onOpenProfile;
  final void Function(int index) onSelectTab;
  final bool embedded;

  const PreFeedCargoScreen({
    super.key,
    required this.user,
    required this.onContinueToFeed,
    required this.onPostLoad,
    required this.onOpenProfile,
    required this.onSelectTab,
    this.embedded = false,
  });

  @override
  State<PreFeedCargoScreen> createState() => _PreFeedCargoScreenState();
}

class _PreFeedCargoScreenState extends State<PreFeedCargoScreen> {
  late Future<List<Map<String, dynamic>>> _loadsFuture;
  late Future<List<Map<String, dynamic>>> _driversFuture;

  @override
  void initState() {
    super.initState();
    _loadsFuture = _fetchLoads();
    _driversFuture = _fetchDrivers();
  }

  Future<Map<String, dynamic>> _authedRequest(String path) async {
    final token = await BackendAuthService().getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not signed in');
    }

    final uri = Uri.parse('${BackendConfig.baseUrl}$path');
    final client = HttpClient();
    try {
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
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

  Future<List<Map<String, dynamic>>> _fetchLoads() async {
    final data = await _authedRequest('/api/threads');
    return (data['threads'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((thread) => (thread['ownerId'] ?? '').toString() == widget.user.id)
        .take(4)
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchDrivers() async {
    final data = await _authedRequest('/api/users?userType=Driver&limit=3');
    return (data['users'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: widget.embedded
          ? null
          : AppBar(
              elevation: 0,
              backgroundColor: AppPalette.card,
              foregroundColor: AppPalette.ink,
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
                eyebrow: localizations.tr('cargoControlTitle'),
                title: 'Run each shipment from one clean home base.',
                subtitle:
                    'Post loads fast, monitor what is moving, and keep driver discovery within reach without crowding the screen.',
                primaryLabel: localizations.tr('postALoad'),
                primaryIcon: Icons.add_circle_outline,
                onPrimaryTap: widget.onPostLoad,
                secondaryLabel: localizations.tr('track'),
                secondaryIcon: Icons.location_on_outlined,
                onSecondaryTap: () => widget.onSelectTab(3),
                metrics: [
                  _HeroMetricData(
                    label: localizations.tr('recentLoads'),
                    value: '4',
                  ),
                  _HeroMetricData(
                    label: localizations.tr('suggestedDrivers'),
                    value: '3',
                  ),
                  _HeroMetricData(
                    label: localizations.tr('profile'),
                    value: 'Live',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SectionHeader(
                title: localizations.tr('quickActions'),
                subtitle: 'Start the next shipment step without digging through tabs.',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.add_box_outlined,
                      title: localizations.tr('postALoad'),
                      subtitle: 'Create a new shipment and start collecting bids.',
                      onTap: widget.onPostLoad,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.person_outline,
                      title: localizations.tr('profile'),
                      subtitle: 'Review your account and notification preferences.',
                      onTap: widget.onOpenProfile,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _SectionHeader(
                title: localizations.tr('recentLoads'),
                subtitle: 'Your most recent shipment activity.',
              ),
              const SizedBox(height: 10),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _loadsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _LoadingList();
                  }
                  final docs = snapshot.data ?? const <Map<String, dynamic>>[];
                  if (docs.isEmpty) {
                    return _EmptyState(
                      title: localizations.tr('noLoadsYet'),
                      subtitle: localizations.tr('postFirstLoadHint'),
                      buttonText: localizations.tr('postALoad'),
                      onTap: widget.onPostLoad,
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
                      final weight = data['weight']?.toString() ?? '-';
                      final unit = (data['weightUnit'] ?? 'kg').toString();
                      final status =
                          (data['deliveryStatus'] ?? 'pending_bids').toString();
                      return _LoadCard(
                        title: '$start -> $end',
                        subtitle:
                            '${localizations.tr('weight')}: $weight $unit',
                        trailing: _StatusPill(status: status),
                        footer:
                            '${localizations.tr('status')}: ${deliveryStatusLabel(status)}',
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 22),
              _SectionHeader(
                title: localizations.tr('suggestedDrivers'),
                subtitle: 'Drivers you may want to engage for similar routes.',
              ),
              const SizedBox(height: 10),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _driversFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _LoadingList();
                  }
                  final docs = snapshot.data ?? const <Map<String, dynamic>>[];
                  if (docs.isEmpty) {
                    return _EmptyState(
                      title: localizations.tr('noSuggestionsYet'),
                      subtitle: localizations.tr('suggestedDriversHint'),
                    );
                  }
                  return ListView.separated(
                    itemCount: docs.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final data = docs[index];
                      final name = (data['name'] ?? 'Driver').toString();
                      final rating =
                          (data['ratingAverage'] as num?)?.toDouble();
                      final truckType = (data['truckType'] ?? 'Any truck').toString();
                      return _LoadCard(
                        title: name,
                        subtitle: truckType,
                        trailing: rating == null
                            ? const SizedBox.shrink()
                            : _RatingPill(rating: rating),
                        footer: localizations.tr('tapFeedToInvite'),
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
              selectedItemColor: AppPalette.ink,
              unselectedItemColor: Colors.grey,
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
                  icon: const Icon(Icons.add_circle_outline),
                  label: localizations.tr('post'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.location_on_outlined),
                  label: localizations.tr('track'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.person_outline),
                  label: localizations.tr('profile'),
                ),
              ],
              onTap: (index) {
                if (index == 0) return;
                if (index == 2) {
                  widget.onPostLoad();
                  return;
                }
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
                color: Colors.black54,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppPalette.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.04 * 255).round()),
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
                color: const Color(0xFFFFEDD5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFFB45309)),
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
                    color: Colors.black54,
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

  const _LoadCard({
    required this.title,
    required this.subtitle,
    required this.footer,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                            color: Colors.black54,
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
                  color: const Color(0xFF475569),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = normalized == 'pending_bids'
        ? Colors.orange
        : normalized == 'delivered'
            ? Colors.green
            : Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha((0.12 * 255).round()),
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

class _RatingPill extends StatelessWidget {
  final double rating;

  const _RatingPill({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '★ ${rating.toStringAsFixed(1)}',
        style: const TextStyle(
          color: Color(0xFFB45309),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppPalette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                  color: Colors.black54,
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
