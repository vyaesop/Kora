import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_localizations.dart';
import '../model/thread_message.dart';
import '../utils/app_theme.dart';
import '../utils/delivery_status.dart';
import '../utils/formatters.dart';
import '../utils/load_categories.dart';
import 'profile_avatar.dart';

class ThreadMessageWidget extends StatelessWidget {
  final ThreadMessage message;
  final VoidCallback onLike;
  final VoidCallback onDisLike;
  final VoidCallback onComment;
  final VoidCallback? onProfileTap;
  final dynamic panelController;
  final String userId;
  final bool showBidButton;
  final bool showBidStatusWhenHidden;

  const ThreadMessageWidget({
    super.key,
    required this.message,
    required this.onLike,
    required this.onDisLike,
    required this.onComment,
    required this.onProfileTap,
    required this.panelController,
    required this.userId,
    this.showBidButton = true,
    this.showBidStatusWhenHidden = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final localizations = AppLocalizations.of(context);
    final statusLabel = deliveryStatusLabel(
      message.deliveryStatus ?? 'pending_bids',
    );
    final statusColor = _statusColor(message.deliveryStatus);
    final relativeTime = _relativeTime(message.timestamp, localizations);
    final senderName = message.senderName.isEmpty
        ? localizations.tr('cargoLabel')
        : message.senderName;
    final isOwnLoad = userId.isNotEmpty && message.ownerId == userId;
    final cardColor = isOwnLoad
        ? (isDark ? const Color(0xFF18283F) : const Color(0xFFF7F3EA))
        : (isDark ? const Color(0xFF142033) : Colors.white);
    final borderColor = isOwnLoad
        ? (isDark ? const Color(0xFF45607C) : const Color(0xFFD7C4A3))
        : (isDark ? const Color(0xFF243247) : const Color(0xFFE5E7EB));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isOwnLoad ? 1.4 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (onProfileTap != null)
                  GestureDetector(
                    onTap: onProfileTap,
                    child: ProfileAvatar(
                      radius: 16,
                      imageUrl: message.senderProfileImageUrl,
                    ),
                  )
                else
                  ProfileAvatar(
                    radius: 16,
                    imageUrl: message.senderProfileImageUrl,
                  ),
                const SizedBox(width: 8),
                if (isOwnLoad) ...[
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF20314A)
                          : const Color(0xFFEADFC7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Your load',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? const Color(0xFFF4E7CF)
                            : const Color(0xFF7A5B24),
                      ),
                    ),
                  ),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        senderName,
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          color: isDark
                              ? const Color(0xFFE5EEF8)
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${localizations.tr('lastUpdated')} - $relativeTime',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha((0.12 * 255).round()),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.manrope(
                      color: statusColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF101B2D)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF243247)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _RouteStopCard(
                          isDark: isDark,
                          label: localizations.tr('departure'),
                          value: message.start,
                          icon: Icons.trip_origin,
                          color: const Color(0xFF5B8C85),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: _RouteConnector(isDark: isDark),
                      ),
                      Expanded(
                        child: _RouteStopCard(
                          isDark: isDark,
                          label: localizations.tr('destination'),
                          value: message.end,
                          icon: Icons.location_on_outlined,
                          color: const Color(0xFFC28C5A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (message.message.trim().isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                message.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  color: isDark
                      ? const Color(0xFFCBD5E1)
                      : Colors.grey.shade700,
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                _tag(
                  isDark: isDark,
                  icon: Icons.scale_outlined,
                  label: formatWeight(message.weight, message.weightUnit),
                ),
                _tag(
                  isDark: isDark,
                  icon: Icons.category_outlined,
                  label: displayLoadType(
                    category: message.category,
                    subtype: message.type,
                  ),
                ),
                if (message.packaging.isNotEmpty)
                  _tag(
                    isDark: isDark,
                    icon: Icons.inventory_2_outlined,
                    label: message.packaging,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    localizations.tr('tapForDetails'),
                    style: GoogleFonts.manrope(
                      color: isDark
                          ? AppPalette.darkTextSoft
                          : Colors.grey.shade600,
                      fontSize: 10.5,
                    ),
                  ),
                ),
                if (showBidButton)
                  ElevatedButton.icon(
                    onPressed: onComment,
                    icon: const Icon(Icons.local_offer_outlined, size: 16),
                    label: Text(localizations.tr('bid')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      elevation: 0,
                    ),
                  )
                else if (showBidStatusWhenHidden)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.green.withAlpha((0.16 * 255).round())
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.green.withAlpha((0.24 * 255).round())
                            : Colors.green.shade100,
                      ),
                    ),
                    child: Text(
                      localizations.tr('bidAlreadyPlaced'),
                      style: GoogleFonts.manrope(
                        color: Colors.green.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String? status) {
    final normalized = normalizeDeliveryStatus(status ?? 'pending_bids');
    switch (normalized) {
      case 'pending_bids':
        return const Color(0xFF2563EB);
      case 'accepted':
        return const Color(0xFF16A34A);
      case 'driving_to_location':
      case 'picked_up':
      case 'on_the_road':
        return const Color(0xFF0EA5E9);
      case 'delivered':
        return const Color(0xFF22C55E);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _relativeTime(DateTime time, AppLocalizations localizations) {
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

  Widget _tag({
    required bool isDark,
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101B2D) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF243247) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: isDark ? const Color(0xFF94A3B8) : Colors.blueGrey,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFE5EEF8) : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteStopCard extends StatelessWidget {
  final bool isDark;
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _RouteStopCard({
    required this.isDark,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF142033) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF243247) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color.withAlpha((0.14 * 255).round()),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 13, color: color),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppPalette.darkTextSoft
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              height: 1.2,
              color: isDark ? const Color(0xFFE5EEF8) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteConnector extends StatelessWidget {
  final bool isDark;

  const _RouteConnector({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final railColor = isDark
        ? const Color(0xFF243247)
        : const Color(0xFFD8E1EC);
    final arrowColor = isDark
        ? AppPalette.darkTextSoft
        : const Color(0xFF64748B);

    return SizedBox(
      width: 28,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 1.5,
            decoration: BoxDecoration(
              color: railColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 4),
          Icon(Icons.arrow_forward_rounded, size: 16, color: arrowColor),
          const SizedBox(height: 4),
          Container(
            height: 1.5,
            decoration: BoxDecoration(
              color: railColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}
