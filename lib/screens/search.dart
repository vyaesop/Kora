import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../model/thread_message.dart';
import '../utils/backend_auth_service.dart';
import '../utils/backend_http.dart';
import '../widgets/thread_message.dart';
import 'comment_screen.dart';
import 'post_comment_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final PanelController _panelController = PanelController();
  final BackendAuthService _authService = BackendAuthService();

  bool _loading = true;
  String? _error;
  String? _currentUserId;
  String? _threadDocForBid;

  final List<String> _types = const ['All', 'Fragile', 'Heavy', 'Food', 'Electronics', 'Other'];
  String _selectedType = 'All';

  List<ThreadMessage> _allThreads = const [];
  Set<String> _myBidThreadIds = const {};
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final userId = await _authService.getCurrentUserId();
    if (!mounted) return;
    setState(() => _currentUserId = userId);

    await _refresh(showLoader: true);
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) => _refresh(showLoader: false));
  }

  Future<void> _refresh({required bool showLoader}) async {
    if (showLoader && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final threadsData = await BackendHttp.request(path: '/api/threads', auth: false);
      final bidsData = await BackendHttp.request(path: '/api/bids/me');

      final threadRows = (threadsData['threads'] is List)
          ? (threadsData['threads'] as List).whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];

      final bidRows = (bidsData['bids'] is List)
          ? (bidsData['bids'] as List).whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];

      final threads = threadRows.map(_toThreadMessage).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      final myBidThreads = <String>{};
      for (final bid in bidRows) {
        final load = bid['load'];
        if (load is Map<String, dynamic>) {
          final id = (load['id'] ?? '').toString();
          if (id.isNotEmpty) myBidThreads.add(id);
        }
      }

      if (!mounted) return;
      setState(() {
        _allThreads = threads;
        _myBidThreadIds = myBidThreads;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  ThreadMessage _toThreadMessage(Map<String, dynamic> row) {
    final owner = row['owner'] is Map<String, dynamic>
        ? row['owner'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return ThreadMessage(
      id: (row['id'] ?? '').toString(),
      docId: (row['id'] ?? '').toString(),
      senderName: (owner['name'] ?? 'Unknown').toString(),
      senderProfileImageUrl: (owner['profileImageUrl'] ?? '').toString(),
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

  List<ThreadMessage> get _filteredThreads {
    final q = _searchController.text.trim().toLowerCase();

    return _allThreads.where((t) {
      if ((t.deliveryStatus ?? 'pending_bids') != 'pending_bids') return false;
      if (_selectedType != 'All' && t.type != _selectedType) return false;

      if (q.isNotEmpty) {
        final hay = '${t.start} ${t.end} ${t.message} ${t.type}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final threads = _filteredThreads;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Loads'),
      ),
      body: SlidingUpPanel(
        controller: _panelController,
        minHeight: 0,
        maxHeight: MediaQuery.of(context).size.height * 0.6,
        panel: _threadDocForBid == null
            ? const SizedBox.shrink()
            : PostCommentScreen(
                threadDoc: _threadDocForBid!,
                panelController: _panelController,
              ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search by route, load type, or message',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('Type: '),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _selectedType,
                        items: _types
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedType = value);
                        },
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _refresh(showLoader: true),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : threads.isEmpty
                          ? const Center(child: Text('No matching loads found.'))
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                              itemCount: threads.length,
                              itemBuilder: (context, index) {
                                final thread = threads[index];
                                final alreadyBid = _myBidThreadIds.contains(thread.docId);

                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CommentScreen(
                                          message: thread,
                                          threadId: thread.docId,
                                        ),
                                      ),
                                    );
                                  },
                                  child: ThreadMessageWidget(
                                    message: thread,
                                    onLike: () {},
                                    onDisLike: () {},
                                    onComment: () {
                                      if (alreadyBid) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('You already placed a bid on this load.'),
                                          ),
                                        );
                                        return;
                                      }
                                      setState(() => _threadDocForBid = thread.docId);
                                      _panelController.open();
                                    },
                                    onProfileTap: () {},
                                    panelController: _panelController,
                                    userId: _currentUserId ?? '',
                                    showBidButton: !alreadyBid,
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
