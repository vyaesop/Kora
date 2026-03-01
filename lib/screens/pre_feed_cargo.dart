import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:Kora/model/user.dart';
import 'package:Kora/utils/delivery_status.dart';
import 'package:Kora/utils/backend_auth_service.dart';
import 'package:Kora/utils/backend_config.dart';
import '../widgets/Language_Switcher.dart';

class PreFeedCargoScreen extends StatelessWidget {
  final UserModel user;
  final VoidCallback onContinueToFeed;
  final VoidCallback onPostLoad;
  final VoidCallback onOpenProfile;
  final void Function(int index) onSelectTab;

  const PreFeedCargoScreen({
    super.key,
    required this.user,
    required this.onContinueToFeed,
    required this.onPostLoad,
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

    final loadsFuture = authedRequest('/api/threads').then((data) {
      final threads = (data['threads'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .where((thread) => (thread['ownerId'] ?? '').toString() == user.id)
          .take(3)
          .toList();
      return threads;
    });

    final driversFuture = authedRequest('/api/users?userType=Driver&limit=2').then((data) {
      return (data['users'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
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
                      'Cargo Control Center',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Post loads, review recent activity, and move quickly to tracking and profile actions.',
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
                'Post a new load or review your recent loads and bids.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onPostLoad,
                      icon: const Icon(Icons.add),
                      label: const Text('Post a Load'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onOpenProfile,
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Profile'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SectionHeader(title: 'Recent Loads'),
              const SizedBox(height: 8),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: loadsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _LoadingList();
                  }
                  final docs = snapshot.data ?? const <Map<String, dynamic>>[];
                  if (docs.isEmpty) {
                    return _EmptyState(
                      title: 'No loads yet',
                      subtitle:
                          'Post your first load to get bids from drivers.',
                      buttonText: 'Create Load',
                      onTap: onPostLoad,
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
                        title: '$start → $end',
                        subtitle: 'Weight: $weight $unit',
                        trailing: _StatusChip(status: status.toString()),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
              _SectionHeader(title: 'Suggested Drivers'),
              const SizedBox(height: 8),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: driversFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _LoadingList();
                  }
                  final docs = snapshot.data ?? const <Map<String, dynamic>>[];
                  if (docs.isEmpty) {
                    return const _EmptyState(
                      title: 'No suggestions yet',
                      subtitle:
                          'We will recommend top drivers based on your routes.',
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
                        subtitle: 'Tap feed to invite for bids',
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
              icon: Icon(Icons.add_circle_outline), label: 'Post'),
          BottomNavigationBarItem(
              icon: Icon(Icons.location_on), label: 'Track'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          if (index == 0) return;
          if (index == 2) {
            onPostLoad();
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
      label: Text('★ $rating', style: const TextStyle(fontSize: 12)),
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
