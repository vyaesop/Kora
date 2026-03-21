import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kora/model/user.dart';
import 'package:kora/utils/delivery_status.dart';
import 'package:kora/utils/backend_auth_service.dart';
import 'package:kora/utils/backend_config.dart';
import 'package:kora/utils/app_theme.dart';
import '../widgets/language_switcher.dart';
import '../app_localizations.dart';

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
      final data = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw) as Map<String, dynamic>;
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
        .take(3)
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchDrivers() async {
    final data = await _authedRequest('/api/users?userType=Driver&limit=2');
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
                )
              ],
            ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.embedded) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${localizations.tr('welcome')}, ${widget.user.name}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const LanguageSwitcher(),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppPalette.card,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.tr('cargoControlTitle'),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      localizations.tr('cargoControlSubtitle'),
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: AppPalette.heroGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.tr('feedTitle'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      localizations.tr('feedSubtitle'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: widget.onContinueToFeed,
                        icon: const Icon(Icons.rss_feed),
                        label: Text(localizations.tr('continueToFeed')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppPalette.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionHeader(
                title: localizations.tr('quickActions'),
                actionText: localizations.tr('continueToFeed'),
                onAction: widget.onContinueToFeed,
              ),
              const SizedBox(height: 6),
              Text(
                localizations.tr('cargoQuickActionsHint'),
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.onPostLoad,
                      icon: const Icon(Icons.add),
                      label: Text(localizations.tr('postALoad')),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onOpenProfile,
                      icon: const Icon(Icons.person_outline),
                      label: Text(localizations.tr('profile')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SectionHeader(title: localizations.tr('recentLoads')),
              const SizedBox(height: 8),
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
                      final start = data['start'] ?? 'Unknown';
                      final end = data['end'] ?? 'Unknown';
                      final weight = data['weight'] ?? '';
                      final unit = data['weightUnit'] ?? '';
                      final status = data['deliveryStatus'] ?? 'pending_bids';
                      return _InfoCard(
                        title: '$start -> $end',
                        subtitle:
                            '${localizations.tr('weight')}: $weight $unit',
                        trailing: _StatusChip(status: status.toString()),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
              _SectionHeader(title: localizations.tr('suggestedDrivers')),
              const SizedBox(height: 8),
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
                      final name = data['name'] ?? 'Driver';
                      final rating = data['ratingAverage'];
                      return _InfoCard(
                        title: name.toString(),
                        subtitle: localizations.tr('tapFeedToInvite'),
                        trailing: rating == null
                            ? const SizedBox.shrink()
                            : _RatingChip(rating: rating),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: widget.onContinueToFeed,
                  child: Text(localizations.tr('continueToFeed')),
                ),
              )
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.embedded
          ? null
          : BottomNavigationBar(
              currentIndex: 0,
              selectedItemColor: const Color(0xFF000000),
              unselectedItemColor: Colors.grey,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
              items: [
                BottomNavigationBarItem(
                    icon: const Icon(Icons.preview),
                    label: localizations.tr('home')),
                BottomNavigationBarItem(
                    icon: const Icon(Icons.rss_feed),
                    label: localizations.tr('feed')),
                BottomNavigationBarItem(
                    icon: const Icon(Icons.add_circle_outline),
                    label: localizations.tr('post')),
                BottomNavigationBarItem(
                    icon: const Icon(Icons.location_on),
                    label: localizations.tr('track')),
                BottomNavigationBarItem(
                    icon: const Icon(Icons.person),
                    label: localizations.tr('profile')),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;

  const _SectionHeader({required this.title, this.actionText, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        if (actionText != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionText!)),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _InfoCard({required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: trailing,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == 'pending_bids'
        ? Colors.orange
        : status == 'in_transit'
            ? Colors.blue
            : Colors.green;
    final label = deliveryStatusLabel(status);
    return Chip(
      label: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
    );
  }
}

class _RatingChip extends StatelessWidget {
  final dynamic rating;
  const _RatingChip({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('* $rating', style: const TextStyle(fontSize: 12)),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        LinearProgressIndicator(minHeight: 2),
        SizedBox(height: 10),
      ],
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
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(subtitle),
            if (buttonText != null && onTap != null) ...[
              const SizedBox(height: 12),
              ElevatedButton(onPressed: onTap, child: Text(buttonText!)),
            ],
          ],
        ),
      ),
    );
  }
}

