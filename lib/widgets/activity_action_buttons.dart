import 'package:flutter/material.dart';
import 'package:kora/screens/notifications_screen.dart';
import 'package:kora/screens/wallet_screen.dart';
import 'package:kora/utils/notification_center_controller.dart';

class ActivityActionButtons extends StatelessWidget {
  final Color? color;

  const ActivityActionButtons({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Wallet',
          onPressed: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const WalletScreen()));
          },
          icon: Icon(Icons.account_balance_wallet_outlined, color: color),
        ),
        ValueListenableBuilder<int>(
          valueListenable: NotificationCenterController.unreadCount,
          builder: (context, unreadCount, _) {
            return IconButton(
              tooltip: 'Notifications',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
              },
              icon: BadgeIcon(
                icon: Icons.notifications_none_rounded,
                count: unreadCount,
                color: color,
              ),
            );
          },
        ),
      ],
    );
  }
}

class BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color? color;

  const BadgeIcon({
    super.key,
    required this.icon,
    required this.count,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: color),
        if (count > 0)
          Positioned(
            right: -7,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(999),
              ),
              constraints: const BoxConstraints(minWidth: 18),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
