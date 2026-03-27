import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../model/thread_message.dart';
import 'profile_avatar.dart';
import '../utils/delivery_status.dart';
import '../app_localizations.dart';

class ThreadMessageWidget extends StatelessWidget {
  final ThreadMessage message;
  final VoidCallback onLike;
  final VoidCallback onDisLike;
  final VoidCallback onComment;
  final VoidCallback onProfileTap;
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
    final statusLabel =
        deliveryStatusLabel(message.deliveryStatus ?? 'pending_bids');
    final statusColor = _statusColor(message.deliveryStatus);
    final relativeTime = _relativeTime(message.timestamp, localizations);
    final senderName = message.senderName.isEmpty
        ? localizations.tr('cargoLabel')
        : message.senderName;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF142033) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF243247) : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).round()),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: onProfileTap,
                      child: ProfileAvatar(
                        radius: 18,
                        imageUrl: message.senderProfileImageUrl,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            senderName,
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color:
                                  isDark ? const Color(0xFFE5EEF8) : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${localizations.tr('lastUpdated')} - $relativeTime',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                    color: statusColor.withAlpha((0.12 * 255).round()),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.manrope(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF101B2D) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          isDark ? const Color(0xFF243247) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: statusColor.withAlpha((0.9 * 255).round()),
                            ),
                          ),
                          Container(
                            width: 2,
                            height: 28,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: Colors.blueGrey.shade200,
                          ),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.rectangle,
                              borderRadius: BorderRadius.circular(3),
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localizations.tr('pickup'),
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.blueGrey.shade500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              message.start,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: isDark
                                    ? const Color(0xFFE5EEF8)
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              localizations.tr('delivery'),
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.blueGrey.shade500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              message.end,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: isDark
                                    ? const Color(0xFFE5EEF8)
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (message.message.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    message.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      color:
                          isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _tag(
                      icon: Icons.scale_outlined,
                      label: '${message.weight} ${message.weightUnit}'.trim(),
                    ),
                    _tag(
                      icon: Icons.category_outlined,
                      label: message.type.isEmpty
                          ? localizations.tr('searchGeneral')
                          : message.type,
                    ),
                    if (message.packaging.isNotEmpty)
                      _tag(
                        icon: Icons.inventory_2_outlined,
                        label: message.packaging,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.touch_app_outlined,
                        size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        localizations.tr('tapForDetails'),
                        style: GoogleFonts.manrope(
                          color: Colors.grey.shade600,
                          fontSize: 12,
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
                              horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      )
                    else if (showBidStatusWhenHidden)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
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
                            fontSize: 11,
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
        ],
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

  Widget _tag({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.blueGrey),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}
