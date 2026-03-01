import 'package:flutter/material.dart';

import '../model/thread_message.dart';

class ThreadMessageWidget extends StatelessWidget {
  final ThreadMessage message;
  final VoidCallback onLike;
  final VoidCallback onDisLike;
  final VoidCallback onComment;
  final VoidCallback onProfileTap;
  final dynamic panelController;
  final String userId;
  final bool showBidButton;

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
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: onProfileTap,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundImage: message.senderProfileImageUrl.isNotEmpty
                        ? NetworkImage(message.senderProfileImageUrl)
                        : null,
                    child: message.senderProfileImageUrl.isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message.senderName.isEmpty ? 'Unknown' : message.senderName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  message.deliveryStatus ?? 'pending_bids',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(message.message),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('Weight', '${message.weight} ${message.weightUnit}'),
                _chip('Type', message.type),
                _chip('From', message.start),
                _chip('To', message.end),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onLike,
                  icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
                  label: Text('${message.likes.length}'),
                ),
                TextButton.icon(
                  onPressed: onDisLike,
                  icon: const Icon(Icons.thumb_down_alt_outlined, size: 18),
                  label: const Text(''),
                ),
                TextButton.icon(
                  onPressed: onComment,
                  icon: const Icon(Icons.mode_comment_outlined, size: 18),
                  label: Text('${message.comments.length}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $value', style: const TextStyle(fontSize: 12)),
    );
  }
}
