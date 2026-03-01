import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:Kora/model/user.dart';
import 'package:Kora/utils/delivery_status.dart';
import 'package:Kora/utils/backend_auth_service.dart';
import 'package:Kora/utils/backend_config.dart';
import '../widgets/Language_Switcher.dart';

class PreFeedDriverScreen extends StatelessWidget {
  final UserModel user;
  final VoidCallback onContinueToFeed;
  final VoidCallback onOpenProfile;
  final void Function(int index) onSelectTab;

  const PreFeedDriverScreen({
    super.key,
    required this.user,
    required this.onContinueToFeed,
    required this.onOpenProfile,
    required this.onSelectTab,
  });

  @override
  Widget build(BuildContext context) {
    Future<Map<String, dynamic>> authedRequest(String path) async {
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

    final suggestedLoadsFuture = authedRequest('/api/threads').then((data) {
      return (data['threads'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .take(5)
          .toList();
    });

    final acceptedIds = (user.acceptedLoads ?? []).take(10).toSet();
    final acceptedLoadsFuture = authedRequest('/api/threads').then((data) {
      final threads = (data['threads'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .where((thread) => acceptedIds.contains((thread['id'] ?? '').toString()))
          .toList();
      return threads;
    });

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 245, 247),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: false,
        title: Text('Welcome, ${user.name}'),
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Driver Operations Hub',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Monitor active jobs, discover new loads, and keep profile documents up to date.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionHeader(
                title: 'Quick Actions',
                actionText: 'Go to Feed',
                onAction: onContinueToFeed,
              ),
              const SizedBox(height: 6),
              const Text(
                'Find loads quickly or update your documents to get more bids.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onContinueToFeed,
                      icon: const Icon(Icons.search),
                      label: const Text('Open Feed'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onOpenProfile,
                      icon: const Icon(Icons.badge_outlined),
                      label: const Text('Update Docs'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SectionHeader(title: 'Active Jobs'),
              const SizedBox(height: 8),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: acceptedLoadsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _LoadingList();
                  }
                  final docs = snapshot.data ?? const <Map<String, dynamic>>[];
                  if (docs.isEmpty) {
                    return const _EmptyState(
                      title: 'No active jobs',
                      subtitle: 'Bid on loads to start earning.',
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
                      final status = data['deliveryStatus'] ?? 'pending_bids';
                      return _InfoCard(
                        title: '$start → $end',
                        subtitle:
                            'Status: ${deliveryStatusLabel(status.toString())}',
                        trailing: const Icon(Icons.chevron_right),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
              _SectionHeader(title: 'Suggested Loads'),
              const SizedBox(height: 8),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: suggestedLoadsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _LoadingList();
                  }
                  final docs = snapshot.data ?? const <Map<String, dynamic>>[];
                  if (docs.isEmpty) {
                    return const _EmptyState(
                      title: 'No suggestions yet',
                      subtitle: 'We will suggest loads based on your routes.',
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
                      return _InfoCard(
                        title: '$start → $end',
                        subtitle: 'Weight: $weight $unit',
                        trailing: ElevatedButton(
                          onPressed: onContinueToFeed,
                          child: const Text('Bid'),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: onContinueToFeed,
                  child: const Text('Continue to Feed'),
                ),
              )
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: const Color(0xFF000000),
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.preview), label: 'Pre-feed'),
          BottomNavigationBarItem(icon: Icon(Icons.rss_feed), label: 'Feed'),
          BottomNavigationBarItem(
              icon: Icon(Icons.local_offer), label: 'My Bids'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          if (index == 0) {
            return;
          }
          onSelectTab(index);
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

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        LinearProgressIndicator(minHeight: 2),
        SizedBox(height: 10),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyState({required this.title, required this.subtitle});

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
          ],
        ),
      ),
    );
  }
}
