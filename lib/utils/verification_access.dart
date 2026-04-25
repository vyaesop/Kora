import 'package:flutter/material.dart';

import 'package:kora/utils/backend_auth_service.dart';

enum VerificationRequirementKind { number, text, photo }

class VerificationRequirement {
  final String key;
  final String label;
  final VerificationRequirementKind kind;

  const VerificationRequirement({
    required this.key,
    required this.label,
    required this.kind,
  });
}

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

  static List<VerificationRequirement> requiredRequirements(String userType) {
    if (userType == 'Driver') {
      return const [
        VerificationRequirement(
          key: 'tinNumber',
          label: 'TIN number',
          kind: VerificationRequirementKind.number,
        ),
        VerificationRequirement(
          key: 'libre',
          label: 'Libre',
          kind: VerificationRequirementKind.text,
        ),
        VerificationRequirement(
          key: 'vehiclePlateNumber',
          label: 'Vehicle plate number',
          kind: VerificationRequirementKind.text,
        ),
        VerificationRequirement(
          key: 'nationalIdPhoto',
          label: 'National ID',
          kind: VerificationRequirementKind.photo,
        ),
        VerificationRequirement(
          key: 'driverLicensePhoto',
          label: 'Driver\'s license',
          kind: VerificationRequirementKind.photo,
        ),
        VerificationRequirement(
          key: 'tradeLicensePhoto',
          label: 'Trade licence photo',
          kind: VerificationRequirementKind.photo,
        ),
      ];
    }

    return const [
      VerificationRequirement(
        key: 'tinNumber',
        label: 'TIN number',
        kind: VerificationRequirementKind.number,
      ),
      VerificationRequirement(
        key: 'nationalIdPhoto',
        label: 'National ID',
        kind: VerificationRequirementKind.photo,
      ),
      VerificationRequirement(
        key: 'tradeRegistrationCertificatePhoto',
        label: 'Trade registration certificate photo',
        kind: VerificationRequirementKind.photo,
      ),
      VerificationRequirement(
        key: 'tradeLicensePhoto',
        label: 'Trade licence photo',
        kind: VerificationRequirementKind.photo,
      ),
    ];
  }

  static List<String> requiredDocuments(String userType) {
    return requiredRequirements(userType).map((item) => item.label).toList();
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
        return 'Your documents are approved and locked. You can post loads or place bids normally. Contact support if changes are needed.';
      case 'submitted':
        return 'Your verification has been sent to the admin team. You can keep browsing while approval is pending.';
      case 'rejected':
        final trimmedNote = (note ?? '').trim();
        if (trimmedNote.isNotEmpty) {
          return 'Admin asked for an update: $trimmedNote';
        }
        return 'Your previous submission needs an update before approval.';
      default:
        return userType == 'Driver'
            ? 'Add your TIN number, libre, vehicle plate number, and required photos to unlock bidding.'
            : 'Add your TIN number and required business photos to unlock posting.';
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

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$actionLabel is locked for now'),
        content: Text(
          'To $actionLabel, complete the verification requirements in Profile > Verification and submit them for admin approval.\n\n${statusDescription(userType: expectedUserType, status: verificationStatus, note: verificationNote)}',
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
