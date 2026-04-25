import 'package:flutter/material.dart';
import 'package:kora/model/thread_message.dart';
import 'package:kora/screens/comment_screen.dart';
import 'package:kora/screens/wallet_screen.dart';
import 'package:kora/utils/app_theme.dart';
import 'package:kora/utils/backend_auth_service.dart';
import 'package:kora/utils/backend_http.dart';
import 'package:kora/utils/backend_transport.dart';
import 'package:kora/utils/error_handler.dart';
import 'package:kora/utils/notification_center_controller.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const int _pageSize = 20;

  final BackendAuthService _authService = BackendAuthService();
  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _markingAllRead = false;
  bool _previewMode = false;
  bool _hasMore = true;
  String? _error;
  int _unreadCount = 0;
  int _nextOffset = 0;
  List<Map<String, dynamic>> _notifications = const [];

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
        !_hasMore ||
        _previewMode) {
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
      final page = await _fetchNotificationsPage(
        offset: 0,
        forceRefresh: forceRefresh,
      );

      if (!mounted) return;
      NotificationCenterController.setUnreadCount(page.unreadCount);
      setState(() {
        _notifications = page.items;
        _unreadCount = page.unreadCount;
        _nextOffset = page.nextOffset;
        _hasMore = page.hasMore;
        _previewMode = false;
        _loading = false;
        _loadingMore = false;
      });
    } on BackendRequestException catch (error) {
      final code = (error.payload?['code'] ?? '').toString();
      if (code != 'ENDPOINT_UNAVAILABLE') {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _loadingMore = false;
          _error = ErrorHandler.getMessage(error);
        });
        return;
      }

      final previewItems = await _buildPreviewNotifications(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      final unread = previewItems.where((item) => item['isRead'] != true).length;
      NotificationCenterController.setUnreadCount(unread);
      setState(() {
        _notifications = previewItems;
        _unreadCount = unread;
        _nextOffset = previewItems.length;
        _hasMore = false;
        _previewMode = true;
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
    if (_loadingMore || !_hasMore || _previewMode) {
      return;
    }

    setState(() => _loadingMore = true);
    try {
      final page = await _fetchNotificationsPage(offset: _nextOffset);
      if (!mounted) return;
      setState(() {
        _notifications = [..._notifications, ...page.items];
        _unreadCount = page.unreadCount;
        _nextOffset = page.nextOffset;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
      NotificationCenterController.setUnreadCount(page.unreadCount);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _error = ErrorHandler.getMessage(error);
      });
    }
  }

  Future<_NotificationPage> _fetchNotificationsPage({
    required int offset,
    bool forceRefresh = false,
  }) async {
    final data = await BackendHttp.request(
      path: '/api/notifications?limit=$_pageSize&offset=$offset',
      cacheTtl: const Duration(seconds: 30),
      forceRefresh: forceRefresh,
    );
    final items = ((data['notifications'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final pagination =
        data['pagination'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return _NotificationPage(
      items: items,
      unreadCount: (data['unreadCount'] as num?)?.toInt() ?? 0,
      hasMore: pagination['hasMore'] == true,
      nextOffset:
          (pagination['nextOffset'] as num?)?.toInt() ?? (offset + items.length),
    );
  }

  Future<List<Map<String, dynamic>>> _buildPreviewNotifications({
    bool forceRefresh = false,
  }) async {
    final user = await _authService.getStoredUserMap() ?? const <String, dynamic>{};
    final userId = (user['id'] ?? '').toString();
    final userType = (user['userType'] ?? 'Cargo').toString();
    final verificationStatus = (user['verificationStatus'] ?? '').toString();

    final items = <Map<String, dynamic>>[];

    if (verificationStatus.isNotEmpty && verificationStatus != 'not_submitted') {
      items.add(
        _previewNotification(
          id: 'preview_verification_$verificationStatus',
          type: 'verification_$verificationStatus',
          title: _verificationTitle(verificationStatus),
          body: _verificationBody(verificationStatus),
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          route: '/profile',
        ),
      );
    }

    if (userType == 'Driver') {
      final data = await BackendHttp.request(
        path: '/api/bids/me?limit=60&offset=0',
        cacheTtl: const Duration(minutes: 2),
        forceRefresh: forceRefresh,
      );
      final bids = ((data['bids'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      for (final bid in bids) {
        final load = bid['load'] as Map<String, dynamic>? ?? const {};
        final threadId = (load['id'] ?? '').toString();
        final routeLabel =
            '${(load['start'] ?? 'Departure').toString()} -> ${(load['end'] ?? 'Destination').toString()}';
        final bidStatus = (bid['status'] ?? 'pending').toString().toLowerCase();
        final deliveryStatus =
            (load['deliveryStatus'] ?? 'pending_bids').toString().toLowerCase();
        final createdAt = DateTime.tryParse((bid['createdAt'] ?? '').toString()) ??
            DateTime.now();

        if (bidStatus == 'accepted') {
          items.add(
            _previewNotification(
              id: 'preview_bid_${bid['id']}_accepted',
              type: 'bid_accepted',
              title: 'Bid accepted',
              body: 'Your offer was accepted for $routeLabel.',
              createdAt: createdAt,
              entityType: 'thread',
              entityId: threadId,
            ),
          );
        } else if (bidStatus == 'rejected' ||
            bidStatus == 'cancelled' ||
            bidStatus == 'withdrawn') {
          items.add(
            _previewNotification(
              id: 'preview_bid_${bid['id']}_closed',
              type: 'bid_closed',
              title: 'Bid update',
              body: 'Your offer for $routeLabel is now $bidStatus.',
              createdAt: createdAt,
              entityType: 'thread',
              entityId: threadId,
            ),
          );
        }

        if (deliveryStatus != 'pending_bids' && deliveryStatus != 'accepted') {
          items.add(
            _previewNotification(
              id: 'preview_delivery_${bid['id']}_$deliveryStatus',
              type: 'delivery_status_changed',
              title: 'Delivery progress updated',
              body:
                  '$routeLabel is now ${deliveryStatus.replaceAll('_', ' ')}.',
              createdAt: createdAt.add(const Duration(minutes: 5)),
              entityType: 'thread',
              entityId: threadId,
            ),
          );
        }
      }
    } else if (userId.isNotEmpty) {
      final data = await BackendHttp.request(
        path: '/api/users/$userId/threads?limit=60&offset=0',
        cacheTtl: const Duration(minutes: 2),
        forceRefresh: forceRefresh,
      );
      final threads = ((data['threads'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      for (final thread in threads) {
        final threadId = (thread['id'] ?? '').toString();
        final routeLabel =
            '${(thread['start'] ?? 'Departure').toString()} -> ${(thread['end'] ?? 'Destination').toString()}';
        final bids = ((thread['bids'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        final createdAt =
            DateTime.tryParse((thread['updatedAt'] ?? thread['createdAt'] ?? '').toString()) ??
                DateTime.now();
        final deliveryStatus =
            (thread['deliveryStatus'] ?? 'pending_bids').toString().toLowerCase();

        if (bids.isNotEmpty) {
          items.add(
            _previewNotification(
              id: 'preview_thread_${threadId}_bids',
              type: 'bid_received',
              title: 'New bid activity',
              body:
                  '${bids.length} ${bids.length == 1 ? 'bid has' : 'bids have'} arrived for $routeLabel.',
              createdAt: createdAt,
              entityType: 'thread',
              entityId: threadId,
            ),
          );
        }

        if (deliveryStatus != 'pending_bids') {
          items.add(
            _previewNotification(
              id: 'preview_thread_${threadId}_status_$deliveryStatus',
              type: 'delivery_status_changed',
              title: 'Shipment status updated',
              body:
                  '$routeLabel is now ${deliveryStatus.replaceAll('_', ' ')}.',
              createdAt: createdAt.add(const Duration(minutes: 3)),
              entityType: 'thread',
              entityId: threadId,
            ),
          );
        }
      }
    }

    items.sort((a, b) {
      final aTime = DateTime.tryParse((a['createdAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = DateTime.tryParse((b['createdAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return items.take(40).toList();
  }

  Map<String, dynamic> _previewNotification({
    required String id,
    required String type,
    required String title,
    required String body,
    required DateTime createdAt,
    String? entityType,
    String? entityId,
    String? route,
  }) {
    return <String, dynamic>{
      'id': id,
      'type': type,
      'title': title,
      'body': body,
      'entityType': entityType,
      'entityId': entityId,
      'route': route,
      'isRead': false,
      'createdAt': createdAt.toIso8601String(),
      'isPreview': true,
    };
  }

  String _verificationTitle(String status) {
    switch (status) {
      case 'approved':
        return 'Verification approved';
      case 'rejected':
        return 'Verification needs attention';
      case 'submitted':
      case 'pending':
        return 'Verification under review';
      default:
        return 'Verification updated';
    }
  }

  String _verificationBody(String status) {
    switch (status) {
      case 'approved':
        return 'Your account is approved for live marketplace actions.';
      case 'rejected':
        return 'Review the feedback in your profile and resubmit your documents.';
      case 'submitted':
      case 'pending':
        return 'Your verification documents were submitted and are waiting for review.';
      default:
        return 'Your verification details were updated.';
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAllRead || _unreadCount == 0) return;
    setState(() => _markingAllRead = true);

    try {
      if (_previewMode) {
        if (!mounted) return;
        NotificationCenterController.setUnreadCount(0);
        setState(() {
          _unreadCount = 0;
          _notifications = _notifications
              .map((item) => {...item, 'isRead': true})
              .toList();
        });
        return;
      }

      await BackendHttp.request(
        path: '/api/notifications/read-all',
        method: 'POST',
        forceRefresh: true,
      );
      if (!mounted) return;
      NotificationCenterController.setUnreadCount(0);
      setState(() {
        _unreadCount = 0;
        _notifications = _notifications
            .map((item) => {...item, 'isRead': true})
            .toList();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.getMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _markingAllRead = false);
      }
    }
  }

  Future<void> _markRead(Map<String, dynamic> notification) async {
    if (notification['isRead'] == true) return;

    final id = (notification['id'] ?? '').toString();
    if (id.isEmpty) return;

    if (_previewMode || notification['isPreview'] == true) {
      if (!mounted) return;
      NotificationCenterController.decrementUnread();
      setState(() {
        _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
        _notifications = _notifications.map((item) {
          if ((item['id'] ?? '').toString() == id) {
            return {...item, 'isRead': true};
          }
          return item;
        }).toList();
      });
      return;
    }

    try {
      final data = await BackendHttp.request(
        path: '/api/notifications/$id/read',
        method: 'PATCH',
        forceRefresh: true,
      );
      final unread = (data['unreadCount'] as num?)?.toInt() ?? _unreadCount;
      NotificationCenterController.setUnreadCount(unread);
      if (!mounted) return;
      setState(() {
        _unreadCount = unread;
        _notifications = _notifications.map((item) {
          if ((item['id'] ?? '').toString() == id) {
            return {...item, 'isRead': true};
          }
          return item;
        }).toList();
      });
    } catch (_) {}
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    await _markRead(notification);

    final route = (notification['route'] ?? '').toString();
    final entityType = (notification['entityType'] ?? '').toString();
    final entityId = (notification['entityId'] ?? '').toString();

    if (route == '/wallet') {
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const WalletScreen()));
      return;
    }

    if (entityType == 'thread' && entityId.isNotEmpty) {
      try {
        final data = await BackendHttp.request(
          path: '/api/threads/$entityId',
          cacheTtl: const Duration(minutes: 2),
          forceRefresh: true,
        );
        final thread = data['thread'] as Map<String, dynamic>?;
        if (thread == null || !mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CommentScreen(
              threadId: entityId,
              message: ThreadMessage.fromApiMap(thread),
            ),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.getMessage(error))),
        );
      }
    }
  }

  IconData _iconForType(String type) {
    if (type.contains('wallet')) return Icons.account_balance_wallet_outlined;
    if (type.contains('verification')) return Icons.verified_user_outlined;
    if (type.contains('delivery')) return Icons.local_shipping_outlined;
    if (type.contains('bid')) return Icons.local_offer_outlined;
    if (type.contains('chat')) return Icons.chat_bubble_outline_rounded;
    return Icons.notifications_none_rounded;
  }

  Color _toneForType(String type) {
    if (type.contains('wallet')) return const Color(0xFF0F9D58);
    if (type.contains('verification')) return const Color(0xFF2563EB);
    if (type.contains('delivery')) return const Color(0xFFF59E0B);
    if (type.contains('bid')) return const Color(0xFF0EA5E9);
    if (type.contains('chat')) return const Color(0xFF7C3AED);
    return const Color(0xFF64748B);
  }

  String _timeLabel(String? raw) {
    final date = raw == null ? null : DateTime.tryParse(raw);
    if (date == null) return 'Just now';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markingAllRead ? null : _markAllRead,
              child: Text(_markingAllRead ? 'Saving...' : 'Mark all read'),
            ),
          IconButton(
            onPressed: () => _load(forceRefresh: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _load(forceRefresh: true),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _notifications.length + (_loadingMore ? 2 : 1),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: AppPalette.heroGradient,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(
                                        (0.14 * 255).round(),
                                      ),
                                      blurRadius: 24,
                                      offset: const Offset(0, 16),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Stay on top of marketplace activity',
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _previewMode
                                          ? 'This screen is in preview mode. It is using live shipment and bid data because the current backend deployment is not serving the notification routes yet.'
                                          : 'Bids, delivery updates, verification changes, chat activity, and wallet movement all land here.',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.white70,
                                        height: 1.45,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        _HeroChip(label: 'Unread: $_unreadCount'),
                                        _HeroChip(
                                          label: _previewMode
                                              ? 'Preview fallback'
                                              : 'Live inbox',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (_notifications.isEmpty) ...[
                                const SizedBox(height: 18),
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color:
                                        isDark ? AppPalette.darkCard : Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: isDark
                                          ? AppPalette.darkOutline
                                          : const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: Text(
                                    'No notifications yet. New bids, settlements, and delivery updates will appear here.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: isDark
                                          ? AppPalette.darkTextSoft
                                          : Colors.black54,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }

                      final itemIndex = index - 1;
                      if (itemIndex >= _notifications.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final notification = _notifications[itemIndex];
                      final type = (notification['type'] ?? '').toString();
                      final unread = notification['isRead'] != true;
                      final tone = _toneForType(type);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () => _openNotification(notification),
                          borderRadius: BorderRadius.circular(22),
                          child: Ink(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: unread
                                  ? (isDark
                                      ? const Color(0xFF172636)
                                      : const Color(0xFFF8FBFD))
                                  : (isDark ? AppPalette.darkCard : Colors.white),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: unread
                                    ? tone.withAlpha((0.35 * 255).round())
                                    : (isDark
                                        ? AppPalette.darkOutline
                                        : const Color(0xFFE5E7EB)),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: tone.withAlpha((0.14 * 255).round()),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(_iconForType(type), color: tone),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              (notification['title'] ?? 'Update')
                                                  .toString(),
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _timeLabel(
                                              notification['createdAt']
                                                  ?.toString(),
                                            ),
                                            style: theme.textTheme.labelMedium
                                                ?.copyWith(
                                                  color: isDark
                                                      ? AppPalette.darkTextSoft
                                                      : Colors.black54,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        (notification['body'] ?? '').toString(),
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: isDark
                                                  ? AppPalette.darkTextSoft
                                                  : Colors.black54,
                                              height: 1.45,
                                            ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          if (_previewMode)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: tone.withAlpha(
                                                  (0.10 * 255).round(),
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                'Preview',
                                                style: theme.textTheme.labelSmall
                                                    ?.copyWith(
                                                      color: tone,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                            ),
                                          if (unread) ...[
                                            if (_previewMode)
                                              const SizedBox(width: 8),
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: tone,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _NotificationPage {
  final List<Map<String, dynamic>> items;
  final int unreadCount;
  final bool hasMore;
  final int nextOffset;

  const _NotificationPage({
    required this.items,
    required this.unreadCount,
    required this.hasMore,
    required this.nextOffset,
  });
}

class _HeroChip extends StatelessWidget {
  final String label;

  const _HeroChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
