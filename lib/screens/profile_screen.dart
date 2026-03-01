import 'package:flutter/material.dart';

import '../model/thread_message.dart';
import '../utils/backend_auth_service.dart';
import '../utils/backend_http.dart';
import '../widgets/thread_message.dart';
import 'comment_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = BackendAuthService();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _user;
  List<ThreadMessage> _myThreads = const [];
  List<ThreadMessage> _acceptedLoads = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  ThreadMessage _threadFromMap(Map<String, dynamic> row, {Map<String, dynamic>? owner}) {
    final ownerData = owner ?? (row['owner'] as Map<String, dynamic>? ?? const <String, dynamic>{});
    return ThreadMessage(
      id: (row['id'] ?? '').toString(),
      docId: (row['id'] ?? '').toString(),
      senderName: (ownerData['name'] ?? _user?['name'] ?? 'Unknown').toString(),
      senderProfileImageUrl: (ownerData['profileImageUrl'] ?? '').toString(),
      message: (row['message'] ?? '').toString(),
      timestamp: DateTime.tryParse((row['createdAt'] ?? '').toString()) ?? DateTime.now(),
      likes: const [],
      comments: const [],
      weight: (row['weight'] as num?)?.toDouble() ?? 0,
      type: (row['type'] ?? '').toString(),
      start: (row['start'] ?? '').toString(),
      end: (row['end'] ?? '').toString(),
      packaging: (row['packaging'] ?? '').toString(),
      weightUnit: (row['weightUnit'] ?? 'kg').toString(),
      startLat: (row['startLat'] as num?)?.toDouble() ?? 0,
      startLng: (row['startLng'] as num?)?.toDouble() ?? 0,
      endLat: (row['endLat'] as num?)?.toDouble() ?? 0,
      endLng: (row['endLng'] as num?)?.toDouble() ?? 0,
      deliveryStatus: row['deliveryStatus']?.toString(),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = await _authService.getCurrentUserId();
      if (userId == null || userId.isEmpty) {
        throw Exception('Not signed in');
      }

      final userData = await BackendHttp.request(path: '/api/users/$userId');
      final user = userData['user'] as Map<String, dynamic>?;
      if (user == null) {
        throw Exception('User not found');
      }

      final threadsData = await BackendHttp.request(path: '/api/users/$userId/threads');
      final threadRows = (threadsData['threads'] is List)
          ? (threadsData['threads'] as List).whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];

      final myThreads = threadRows.map((row) => _threadFromMap(row, owner: user)).toList();

      final myBidsData = await BackendHttp.request(path: '/api/bids/me');
      final bidRows = (myBidsData['bids'] is List)
          ? (myBidsData['bids'] as List).whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];

      final acceptedLoads = <ThreadMessage>[];
      for (final bid in bidRows) {
        final status = (bid['status'] ?? '').toString().toLowerCase();
        if (status != 'accepted' && status != 'completed') continue;

        final load = bid['load'];
        if (load is Map<String, dynamic>) {
          acceptedLoads.add(_threadFromMap(load));
        }
      }

      if (!mounted) return;
      setState(() {
        _user = user;
        _myThreads = myThreads;
        _acceptedLoads = acceptedLoads;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _signOut() async {
    await _authService.clearSession();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _threadList(List<ThreadMessage> threads) {
    if (threads.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No items yet.'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: threads.length,
      itemBuilder: (context, index) {
        final thread = threads[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CommentScreen(message: thread, threadId: thread.docId),
              ),
            );
          },
          child: ThreadMessageWidget(
            message: thread,
            onLike: () {},
            onDisLike: () {},
            onComment: () {},
            onProfileTap: () {},
            panelController: null,
            userId: (_user?['id'] ?? '').toString(),
            showBidButton: false,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(child: Text(_error!)),
      );
    }

    final user = _user ?? const <String, dynamic>{};
    final ratingAvg = (user['ratingAverage'] as num?)?.toDouble() ?? 0;
    final ratingCount = (user['ratingCount'] as num?)?.toInt() ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: _signOut,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (user['name'] ?? 'Unknown').toString(),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text((user['email'] ?? '').toString()),
                    Text('Type: ${(user['userType'] ?? 'Cargo').toString()}'),
                    Text('Rating: ${ratingAvg.toStringAsFixed(2)} ($ratingCount)'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('My Loads', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            _threadList(_myThreads),
            const SizedBox(height: 16),
            const Text('Accepted Loads', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            _threadList(_acceptedLoads),
          ],
        ),
      ),
    );
  }
}
