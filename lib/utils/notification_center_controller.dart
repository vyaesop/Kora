import 'package:flutter/foundation.dart';

import 'backend_http.dart';

class NotificationCenterController {
  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  static Future<void> refreshUnreadCount({bool forceRefresh = false}) async {
    try {
      final data = await BackendHttp.request(
        path: '/api/notifications/summary',
        cacheTtl: const Duration(seconds: 12),
        forceRefresh: forceRefresh,
      );
      unreadCount.value = (data['unreadCount'] as num?)?.toInt() ?? 0;
    } catch (_) {}
  }

  static void setUnreadCount(int value) {
    unreadCount.value = value < 0 ? 0 : value;
  }

  static void decrementUnread() {
    if (unreadCount.value > 0) {
      unreadCount.value = unreadCount.value - 1;
    }
  }
}
