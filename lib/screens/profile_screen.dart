import 'package:flutter/material.dart';

import 'package:kora/app_localizations.dart';
import 'package:kora/model/thread_message.dart';
import 'package:kora/screens/notifications_screen.dart';
import 'package:kora/screens/settings_screen.dart';
import 'package:kora/screens/verification_documents_screen.dart';
import 'package:kora/screens/wallet_screen.dart';
import 'package:kora/utils/app_theme.dart';
import 'package:kora/utils/backend_auth_service.dart';
import 'package:kora/utils/backend_http.dart';
import 'package:kora/utils/error_handler.dart';
import 'package:kora/utils/verification_access.dart';
import 'package:kora/widgets/document_image.dart';
import 'package:kora/widgets/activity_action_buttons.dart';
import 'package:kora/widgets/profile_avatar.dart';

class ProfileScreen extends StatefulWidget {
  final Future<void> Function()? onReplayTour;

  const ProfileScreen({super.key, this.onReplayTour});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = BackendAuthService();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _user;
  List<ThreadMessage> _acceptedLoads = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  ThreadMessage _threadFromMap(
    Map<String, dynamic> row, {
    Map<String, dynamic>? owner,
  }) {
    if (owner == null) return ThreadMessage.fromApiMap(row);
    return ThreadMessage.fromApiMap({...row, 'owner': owner});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = await _authService.getCurrentUserId();
      if (userId == null || userId.isEmpty) {
        throw Exception('Not signed in');
      }

      final userData = await BackendHttp.request(path: '/api/users/$userId');
      final user = userData['user'] as Map<String, dynamic>?;
      if (user == null) {
        throw Exception('User not found');
      }

      final myBidsData = await BackendHttp.request(path: '/api/bids/me');
      final bidRows = (myBidsData['bids'] is List)
          ? (myBidsData['bids'] as List)
                .whereType<Map<String, dynamic>>()
                .toList()
          : <Map<String, dynamic>>[];

      final acceptedLoads = <ThreadMessage>[];
      for (final bid in bidRows) {
        final status = (bid['status'] ?? '').toString().toLowerCase();
        if (status != 'accepted' && status != 'completed') continue;
        final load = bid['load'];
        if (load is Map<String, dynamic>) {
          acceptedLoads.add(_threadFromMap(load));
        }
      }

      if (!mounted) return;
      setState(() {
        _user = user;
        _acceptedLoads = acceptedLoads;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorHandler.getMessage(e);
      });
    }
  }

  Future<void> _openVerification() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const VerificationDocumentsScreen()),
    );
    if (changed == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(localizations.tr('profile'))),
        body: Center(child: Text(_error!)),
      );
    }

    final user = _user ?? const <String, dynamic>{};
    final ratingAvg = (user['ratingAverage'] as num?)?.toDouble() ?? 0;
    final ratingCount = (user['ratingCount'] as num?)?.toInt() ?? 0;
    final verification = VerificationAccess.normalizeStatus(
      user['verificationStatus']?.toString(),
    );
    final userType = (user['userType'] ?? 'Cargo').toString();
    final address = user['address']?.toString();
    final truckType = user['truckType']?.toString();
    final verificationNote = user['verificationNote']?.toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppPalette.darkCard : Colors.white;
    final cardBorder = isDark
        ? AppPalette.darkOutline
        : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(localizations.tr('profile')),
        actions: [
          const ActivityActionButtons(),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      SettingsScreen(onReplayTour: widget.onReplayTour),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppPalette.heroGradient,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.14 * 255).round()),
                    blurRadius: 24,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ProfileAvatar(
                        imageUrl: user['profileImageUrl']?.toString(),
                        radius: 34,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (user['name'] ?? 'Unknown').toString(),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (user['email'] ?? '').toString(),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HeroChip(label: userType),
                      // _HeroChip(
                      //   label:
                      //       'Verification: ${VerificationAccess.statusTitle(verification)}',
                      // ),
                      _HeroChip(
                        label:
                            '${localizations.tr('ratingLabel')}: ${ratingAvg.toStringAsFixed(1)} ($ratingCount)',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      // Expanded(
                      //   child: _ProfileMetricCard(
                      //     label: localizations.tr('myLoads'),
                      //     value: _myThreads.length.toString(),
                      //   ),
                      // ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ProfileMetricCard(
                          label: localizations.tr('acceptedLoads'),
                          value: _acceptedLoads.length.toString(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _SectionTitle(
              title: 'Account details',
              subtitle: 'Important profile information.',
            ),
            const SizedBox(height: 10),
            _InfoCard(
              color: cardColor,
              borderColor: cardBorder,
              children: [
                _InfoRow(label: localizations.tr('typeLabel'), value: userType),
                if (address != null && address.isNotEmpty)
                  _InfoRow(label: 'Address', value: address),
                if (truckType != null && truckType.isNotEmpty)
                  _InfoRow(
                    label: localizations.tr('truckTypeLabel'),
                    value: truckType,
                  ),
                _InfoRow(
                  label: 'Verification status',
                  value: VerificationAccess.statusTitle(verification),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _SectionTitle(
              title: 'Verification',
              subtitle:
                  'Upload the required documents and monitor admin review.',
            ),
            const SizedBox(height: 10),
            _InfoCard(
              color: cardColor,
              borderColor: cardBorder,
              children: [
                _VerificationSummaryCard(
                  user: user,
                  userType: userType,
                  status: verification,
                  note: verificationNote,
                  onOpenVerification: _openVerification,
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _SectionTitle(
              title: 'Activity hub',
              subtitle:
                  'Jump into notifications, wallet balance, and marketplace updates.',
            ),
            const SizedBox(height: 10),
            _InfoCard(
              color: cardColor,
              borderColor: cardBorder,
              children: [
                const _ProfileActionTile(
                  title: 'Wallet',
                  subtitle:
                      'Track top-ups, reserved load funds, and completed delivery earnings.',
                  icon: Icons.account_balance_wallet_outlined,
                  destination: 'wallet',
                ),
                Divider(color: cardBorder),
                const _ProfileActionTile(
                  title: 'Notifications',
                  subtitle:
                      'See bids, delivery milestones, chat activity, verification, and wallet updates.',
                  icon: Icons.notifications_none_rounded,
                  destination: 'notifications',
                ),
              ],
            ),
            // const SizedBox(height: 18),
            // _SectionTitle(
            //   title: localizations.tr('myLoads'),
            //   subtitle: 'Your posted or owned shipments.',
            // ),
            // const SizedBox(height: 10),
            // _threadList(_myThreads),
            // const SizedBox(height: 18),
            // _SectionTitle(
            //   title: localizations.tr('acceptedLoads'),
            //   subtitle: 'Loads currently awarded to you.',
            // ),
            // const SizedBox(height: 10),
            // _threadList(_acceptedLoads),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? AppPalette.darkText : AppPalette.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isDark ? AppPalette.darkTextSoft : Colors.black54,
          ),
        ),
      ],
    );
  }
}

class _HeroChip extends StatelessWidget {
  final String label;

  const _HeroChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ProfileMetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileMetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  final Color color;
  final Color borderColor;

  const _InfoCard({
    required this.children,
    required this.color,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? AppPalette.darkTextSoft : Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppPalette.darkText : AppPalette.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String destination;

  const _ProfileActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? AppPalette.darkSurfaceRaised : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark ? AppPalette.darkTextSoft : Colors.black54,
              height: 1.4,
            ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        final Widget screen = destination == 'wallet'
            ? const WalletScreen()
            : const NotificationsScreen();
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
      },
    );
  }
}

class _VerificationSummaryCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final String userType;
  final String status;
  final String? note;
  final VoidCallback onOpenVerification;

  const _VerificationSummaryCard({
    required this.user,
    required this.userType,
    required this.status,
    required this.note,
    required this.onOpenVerification,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = switch (VerificationAccess.normalizeStatus(status)) {
      'approved' => const Color(0xFF16A34A),
      'submitted' => const Color(0xFFF59E0B),
      'rejected' => const Color(0xFFDC2626),
      _ => const Color(0xFF0EA5E9),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(
              ((isDark ? 0.24 : 0.10) * 255).round(),
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                VerificationAccess.statusTitle(status),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                VerificationAccess.statusDescription(
                  userType: userType,
                  status: status,
                  note: note,
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Required verification items',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ...VerificationAccess.requiredRequirements(userType).map((item) {
          final value = switch (item.key) {
            'tinNumber' => user['tinNumber']?.toString(),
            'libre' => user['libre']?.toString(),
            'vehiclePlateNumber' => user['licensePlate']?.toString(),
            'nationalIdPhoto' => user['idPhoto']?.toString(),
            'driverLicensePhoto' => user['licenseNumberPhoto']?.toString(),
            'tradeLicensePhoto' => user['tradeLicensePhoto']?.toString(),
            'tradeRegistrationCertificatePhoto' =>
              user['tradeRegistrationCertificatePhoto']?.toString(),
            _ => null,
          };
          final isPhoto = item.kind == VerificationRequirementKind.photo;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DocumentStatusRow(
              title: item.label,
              isUploaded: (value ?? '').trim().isNotEmpty,
              valueText: isPhoto ? null : value,
              imageSource: isPhoto ? value : null,
            ),
          );
        }),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onOpenVerification,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(
              VerificationAccess.normalizeStatus(status) == 'approved'
                  ? 'Review documents'
                  : 'Open verification',
            ),
          ),
        ),
      ],
    );
  }
}

class _DocumentStatusRow extends StatelessWidget {
  final String title;
  final bool isUploaded;
  final String? valueText;
  final String? imageSource;

  const _DocumentStatusRow({
    required this.title,
    required this.isUploaded,
    this.valueText,
    required this.imageSource,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkSurfaceRaised : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppPalette.darkOutline : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          if (imageSource != null)
            SizedBox(
              width: 56,
              height: 56,
              child: DocumentImage(source: imageSource, borderRadius: 14),
            )
          else
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDark ? AppPalette.darkCard : const Color(0xFFEDF2F7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.badge_outlined,
                color: isDark
                    ? AppPalette.darkTextSoft
                    : const Color(0xFF64748B),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  valueText != null
                      ? (isUploaded ? 'Added' : 'Missing')
                      : (isUploaded ? 'Uploaded' : 'Missing'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isUploaded
                        ? const Color(0xFF16A34A)
                        : (isDark
                              ? AppPalette.darkTextSoft
                              : const Color(0xFF64748B)),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if ((valueText ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    valueText!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppPalette.darkTextSoft
                          : const Color(0xFF475569),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
