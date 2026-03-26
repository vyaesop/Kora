import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../app_localizations.dart';
import '../model/thread_message.dart';
import '../utils/app_theme.dart';
import '../utils/backend_auth_service.dart';
import '../utils/backend_http.dart';
import '../utils/error_handler.dart';
import '../widgets/thread_message.dart';
import 'comment_screen.dart';
import 'post_comment_screen.dart';

class SearchScreen extends StatefulWidget {
  final bool showSearchField;

  const SearchScreen({
    super.key,
    this.showSearchField = true,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const Color _ink = AppPalette.ink;
  static const Color _inkSoft = AppPalette.inkSoft;
  static const Color _surface = AppPalette.surface;
  static const Color _card = AppPalette.card;
  static const Color _accent = AppPalette.accent;
  static const Color _accentWarm = AppPalette.accentWarm;
  static const int _pageSize = 12;

  final TextEditingController _searchController = TextEditingController();
  final PanelController _panelController = PanelController();
  final BackendAuthService _authService = BackendAuthService();
  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  String? _currentUserId;
  String? _threadDocForBid;
  DateTime? _lastUpdated;
  int _nextOffset = 0;

  final List<String> _types = const [
    'All',
    'General',
    'Coffee',
    'Fuel',
    'Food',
    'Fertilizer',
    'Construction Materials',
    'Heavy Machinery',
    'Livestock',
  ];
  String _selectedType = 'All';
  bool _showClosed = false;

  List<ThreadMessage> _allThreads = const [];
  Set<String> _myBidThreadIds = const {};
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final userId = await _authService.getCurrentUserId();
    if (!mounted) return;
    setState(() => _currentUserId = userId);

    await _refresh(showLoader: true);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _loading || _loadingMore || !_hasMore) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 360) {
      _loadMore();
    }
  }

  Future<void> _refresh({required bool showLoader}) async {
    if (showLoader && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final bidsData = await BackendHttp.request(path: '/api/bids/me');
      final myBidThreads = _extractBidThreadIds(bidsData);
      final page = await _fetchThreadsPage(offset: 0);

      if (!mounted) return;
      setState(() {
        _myBidThreadIds = myBidThreads;
        _allThreads = page.threads;
        _hasMore = page.hasMore;
        _nextOffset = page.nextOffset;
        _loading = false;
        _loadingMore = false;
        _error = null;
        _lastUpdated = DateTime.now();
      });

      await _ensureVisibleResults();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = ErrorHandler.getMessage(e);
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;

    setState(() => _loadingMore = true);
    try {
      final page = await _fetchThreadsPage(offset: _nextOffset);
      if (!mounted) return;
      setState(() {
        _allThreads = [..._allThreads, ...page.threads];
        _hasMore = page.hasMore;
        _nextOffset = page.nextOffset;
        _loadingMore = false;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _error = ErrorHandler.getMessage(e);
      });
    }
  }

  Future<void> _ensureVisibleResults() async {
    while (mounted &&
        !_loading &&
        !_loadingMore &&
        _hasMore &&
        (_filteredThreads.isEmpty ||
            (_hasActiveFilters && _filteredThreads.length < 4))) {
      await _loadMore();
    }
  }

  Future<_ThreadsPage> _fetchThreadsPage({required int offset}) async {
    final data = await BackendHttp.request(
      path: '/api/threads?limit=$_pageSize&offset=$offset',
      auth: false,
    );

    final threadRows = (data['threads'] is List)
        ? (data['threads'] as List).whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];
    final pagination =
        data['pagination'] as Map<String, dynamic>? ?? const <String, dynamic>{};

    final threads = threadRows.map(_toThreadMessage).toList();
    final hasMore = pagination['hasMore'] == true;
    final nextOffset = (pagination['nextOffset'] as num?)?.toInt() ??
        (offset + threads.length);

    return _ThreadsPage(
      threads: threads,
      hasMore: hasMore,
      nextOffset: nextOffset,
    );
  }

  Set<String> _extractBidThreadIds(Map<String, dynamic> bidsData) {
    final bidRows = (bidsData['bids'] is List)
        ? (bidsData['bids'] as List).whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];

    final myBidThreads = <String>{};
    for (final bid in bidRows) {
      final load = bid['load'];
      if (load is Map<String, dynamic>) {
        final id = (load['id'] ?? '').toString();
        if (id.isNotEmpty) {
          myBidThreads.add(id);
        }
      }
    }
    return myBidThreads;
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
      timestamp:
          DateTime.tryParse((row['createdAt'] ?? '').toString()) ?? DateTime.now(),
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
      if (!_showClosed && (t.deliveryStatus ?? 'pending_bids') != 'pending_bids') {
        return false;
      }
      if (_selectedType != 'All' && t.type != _selectedType) {
        return false;
      }
      if (widget.showSearchField && q.isNotEmpty) {
        final hay = '${t.start} ${t.end} ${t.message} ${t.type}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  String _typeLabel(String type, AppLocalizations localizations) {
    switch (type) {
      case 'All':
        return localizations.tr('searchAll');
      case 'General':
        return localizations.tr('searchGeneral');
      default:
        return type;
    }
  }

  String _formatLastUpdated(DateTime time, AppLocalizations localizations) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 30) return localizations.tr('justNow');
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ${localizations.tr('ago')}';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ${localizations.tr('ago')}';
    }
    return '${diff.inDays}d ${localizations.tr('ago')}';
  }

  bool get _hasSearch => _searchController.text.trim().isNotEmpty;

  bool get _hasActiveFilters =>
      (widget.showSearchField && _hasSearch) ||
      _selectedType != 'All' ||
      _showClosed;

  void _clearSearch() {
    _searchController.clear();
    setState(() {});
    unawaited(_ensureVisibleResults());
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _selectedType = 'All';
      _showClosed = false;
    });
    unawaited(_ensureVisibleResults());
  }

  Widget _buildFilters(AppLocalizations localizations) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.04 * 255).round()),
            blurRadius: 16,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.showSearchField ? localizations.tr('searchLoads') : 'Filters',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
              const Spacer(),
              if (_hasActiveFilters)
                TextButton(
                  onPressed: _resetFilters,
                  child: Text(
                    widget.showSearchField
                        ? localizations.tr('cancel')
                        : localizations.tr('viewAll'),
                    style: GoogleFonts.manrope(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (widget.showSearchField) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              onChanged: (_) {
                setState(() {});
                unawaited(_ensureVisibleResults());
              },
              style: GoogleFonts.manrope(fontSize: 14),
              decoration: InputDecoration(
                hintText: localizations.tr('searchHint'),
                hintStyle: GoogleFonts.manrope(color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _hasSearch
                    ? IconButton(
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.close),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _types.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final type = _types[index];
                final selected = _selectedType == type;
                return ChoiceChip(
                  label: Text(_typeLabel(type, localizations)),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _selectedType = type);
                    unawaited(_ensureVisibleResults());
                  },
                  selectedColor: const Color(0xFFE0F2FE),
                  backgroundColor: const Color(0xFFF1F5F9),
                  labelStyle: GoogleFonts.manrope(
                    color: selected ? const Color(0xFF0B3B82) : _inkSoft,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilterChip(
                label: Text(localizations.tr('includeClosedLoads')),
                selected: _showClosed,
                onSelected: (value) {
                  setState(() => _showClosed = value);
                  unawaited(_ensureVisibleResults());
                },
                labelStyle: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600,
                  color: _showClosed ? _ink : Colors.grey.shade700,
                ),
                selectedColor: const Color(0xFFEFF6FF),
                backgroundColor: const Color(0xFFF8FAFC),
                avatar: Icon(
                  _showClosed ? Icons.check_circle : Icons.circle_outlined,
                  size: 18,
                  color: _showClosed ? _accent : Colors.grey.shade400,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  _showClosed
                      ? localizations.tr('showingAllLoads')
                      : localizations.tr('showingOpenOnly'),
                  textAlign: TextAlign.right,
                  style: GoogleFonts.manrope(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final threads = _filteredThreads;
    final bottomSpacing = MediaQuery.of(context).padding.bottom + 116.0;

    return Scaffold(
      backgroundColor: _surface,
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
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -120,
                right: -80,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        _accent.withAlpha((0.18 * 255).round()),
                        _accent.withAlpha((0.02 * 255).round()),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -140,
                left: -60,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        _accentWarm.withAlpha((0.16 * 255).round()),
                        _accentWarm.withAlpha((0.02 * 255).round()),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Column(
                  children: [
                    _buildFilters(localizations),
                    if (_lastUpdated != null)
                      Padding(
                        padding:
                            const EdgeInsets.only(left: 18, right: 18, bottom: 6),
                        child: Row(
                          children: [
                            Icon(Icons.schedule,
                                size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 6),
                            Text(
                              '${localizations.tr('lastUpdated')}: ${_formatLastUpdated(_lastUpdated!, localizations)}',
                              style: GoogleFonts.manrope(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: _loading
                            ? const Center(
                                key: ValueKey('loading'),
                                child: CircularProgressIndicator(),
                              )
                            : _error != null
                                ? Center(
                                    key: const ValueKey('error'),
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.error_outline,
                                              size: 34,
                                              color: Colors.red.shade300),
                                          const SizedBox(height: 10),
                                          Text(
                                            _error!,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.manrope(
                                              fontSize: 14,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          ElevatedButton.icon(
                                            onPressed: () =>
                                                _refresh(showLoader: true),
                                            icon: const Icon(Icons.refresh),
                                            label: Text(
                                                localizations.tr('refresh')),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : threads.isEmpty
                                    ? RefreshIndicator(
                                        onRefresh: () =>
                                            _refresh(showLoader: false),
                                        child: SingleChildScrollView(
                                          physics:
                                              const AlwaysScrollableScrollPhysics(),
                                          child: SizedBox(
                                            height:
                                                MediaQuery.of(context).size.height *
                                                    0.48,
                                            child: Center(
                                              key: const ValueKey('empty'),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                      Icons.inventory_2_outlined,
                                                      size: 64,
                                                      color:
                                                          Colors.grey.shade300),
                                                  const SizedBox(height: 16),
                                                  Text(
                                                    localizations
                                                        .tr('noLoadsAvailable'),
                                                    style: GoogleFonts.manrope(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    _hasMore
                                                        ? 'Loading more loads for your filters...'
                                                        : _hasActiveFilters
                                                            ? 'Try adjusting your filters'
                                                            : 'Check back later for new loads',
                                                    style: GoogleFonts.manrope(
                                                      fontSize: 14,
                                                      color:
                                                          Colors.grey.shade500,
                                                    ),
                                                  ),
                                                  if (_hasActiveFilters &&
                                                      !_hasMore) ...[
                                                    const SizedBox(height: 16),
                                                    OutlinedButton.icon(
                                                      onPressed: _resetFilters,
                                                      icon: const Icon(
                                                          Icons.filter_alt_off),
                                                      label: Text(
                                                        localizations
                                                            .tr('viewAll'),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : RefreshIndicator(
                                        key: const ValueKey('list'),
                                        onRefresh: () =>
                                            _refresh(showLoader: false),
                                        child: ListView.separated(
                                          controller: _scrollController,
                                          padding: EdgeInsets.fromLTRB(
                                            16,
                                            4,
                                            16,
                                            bottomSpacing,
                                          ),
                                          itemCount:
                                              threads.length + (_loadingMore ? 1 : 0),
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(height: 12),
                                          itemBuilder: (context, index) {
                                            if (index >= threads.length) {
                                              return const Padding(
                                                padding: EdgeInsets.symmetric(
                                                    vertical: 8),
                                                child: Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                ),
                                              );
                                            }

                                            final thread = threads[index];
                                            final alreadyBid =
                                                _myBidThreadIds.contains(
                                              thread.docId,
                                            );

                                            return GestureDetector(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        CommentScreen(
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
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          localizations.tr(
                                                              'bidAlreadyPlaced'),
                                                        ),
                                                      ),
                                                    );
                                                    return;
                                                  }
                                                  setState(() =>
                                                      _threadDocForBid =
                                                          thread.docId);
                                                  _panelController.open();
                                                },
                                                onProfileTap: () {},
                                                panelController:
                                                    _panelController,
                                                userId: _currentUserId ?? '',
                                                showBidButton: !alreadyBid,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreadsPage {
  final List<ThreadMessage> threads;
  final bool hasMore;
  final int nextOffset;

  const _ThreadsPage({
    required this.threads,
    required this.hasMore,
    required this.nextOffset,
  });
}
