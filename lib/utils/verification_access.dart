import 'package:flutter/material.dart';

import 'package:kora/utils/backend_auth_service.dart';

class VerificationAccess {
  static String normalizeStatus(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    if (value == 'pending') {
      return 'submitted';
    }
    if (value.isEmpty) {
      return 'not_submitted';
    }
    return value;
  }

  static bool isApproved(String? raw) => normalizeStatus(raw) == 'approved';

  static List<String> requiredDocuments(String userType) {
    return userType == 'Driver'
        ? const ['National ID', 'Driver\'s license']
        : const ['National ID'];
  }

  static String statusTitle(String? raw) {
    switch (normalizeStatus(raw)) {
      case 'approved':
        return 'Approved';
      case 'submitted':
        return 'In review';
      case 'rejected':
        return 'Needs update';
      default:
        return 'Not submitted';
    }
  }

  static String statusDescription({
    required String userType,
    String? status,
    String? note,
  }) {
    final normalized = normalizeStatus(status);
    switch (normalized) {
      case 'approved':
        return 'Your documents are approved. You can post loads or place bids normally.';
      case 'submitted':
        return 'Your documents are with the admin team now. You can explore the app while approval is pending.';
      case 'rejected':
        final trimmedNote = (note ?? '').trim();
        if (trimmedNote.isNotEmpty) {
          return 'Admin asked for an update: $trimmedNote';
        }
        return 'Your previous submission needs an update before approval.';
      default:
        final docs = requiredDocuments(userType).join(' and ');
        return 'Upload $docs from your profile to unlock restricted actions.';
    }
  }

  static Future<Map<String, dynamic>?> refreshCurrentUserMap() async {
    final authService = BackendAuthService();
    await authService.restoreSession();
    return authService.getStoredUserMap();
  }

  static Future<bool> ensureVerifiedForAction(
    BuildContext context, {
    required String expectedUserType,
    required String actionLabel,
    required VoidCallback onOpenProfile,
  }) async {
    final user = await refreshCurrentUserMap();
    final userType = (user?['userType'] ?? '').toString();
    final verificationStatus = user?['verificationStatus']?.toString();
    final verificationNote = user?['verificationNote']?.toString();

    if (userType == expectedUserType && isApproved(verificationStatus)) {
      return true;
    }

    if (!context.mounted) {
      return false;
    }

    final docs = requiredDocuments(expectedUserType).join(' and ');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$actionLabel is locked for now'),
        content: Text(
          'To $actionLabel, upload $docs from Profile > Verification and submit them for admin approval.\n\n${statusDescription(userType: expectedUserType, status: verificationStatus, note: verificationNote)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onOpenProfile();
            },
            child: const Text('Open profile'),
          ),
        ],
      ),
    );
    return false;
  }
}
