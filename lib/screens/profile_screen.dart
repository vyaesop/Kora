import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kora/app_localizations.dart';
import 'package:kora/model/thread_message.dart';
import 'package:kora/screens/verification_documents_screen.dart';
import 'package:kora/utils/app_theme.dart';
import 'package:kora/utils/backend_auth_service.dart';
import 'package:kora/utils/backend_http.dart';
import 'package:kora/utils/error_handler.dart';
import 'package:kora/utils/verification_access.dart';
import 'package:kora/widgets/document_image.dart';
import 'package:kora/widgets/profile_avatar.dart';
import 'package:kora/widgets/thread_message.dart';
import 'comment_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final Future<void> Function()? onReplayTour;

  const ProfileScreen({
    super.key,
    this.onReplayTour,
  });

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const String _pushNotificationsKey = 'profile_push_notifications';
  static const String _bidAlertsKey = 'profile_bid_alerts';
  static const String _loadMatchesKey = 'profile_load_matches';
  static const String _marketingUpdatesKey = 'profile_marketing_updates';
  static const String _darkModeKey = 'profile_dark_mode';

  final _authService = BackendAuthService();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _user;
  List<ThreadMessage> _myThreads = const [];
  List<ThreadMessage> _acceptedLoads = const [];

  bool _pushNotifications = true;
  bool _bidAlerts = true;
  bool _loadMatches = true;
  bool _marketingUpdates = false;
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  ThreadMessage _threadFromMap(
    Map<String, dynamic> row, {
    Map<String, dynamic>? owner,
  }) {
    final ownerData =
        owner ?? (row['owner'] as Map<String, dynamic>? ?? const <String, dynamic>{});
    return ThreadMessage(
      id: (row['id'] ?? '').toString(),
      docId: (row['id'] ?? '').toString(),
      senderName: (ownerData['name'] ?? _user?['name'] ?? 'Unknown').toString(),
      senderProfileImageUrl: (ownerData['profileImageUrl'] ?? '').toString(),
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

      final prefs = await SharedPreferences.getInstance();
      final userData = await BackendHttp.request(path: '/api/users/$userId');
      final user = userData['user'] as Map<String, dynamic>?;
      if (user == null) {
        throw Exception('User not found');
      }

      final threadsData = await BackendHttp.request(path: '/api/users/$userId/threads');
      final threadRows = (threadsData['threads'] is List)
          ? (threadsData['threads'] as List)
              .whereType<Map<String, dynamic>>()
              .toList()
          : <Map<String, dynamic>>[];

      final myThreads = threadRows.map((row) => _threadFromMap(row, owner: user)).toList();

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
        _myThreads = myThreads;
        _acceptedLoads = acceptedLoads;
        _pushNotifications = prefs.getBool(_pushNotificationsKey) ?? true;
        _bidAlerts = prefs.getBool(_bidAlertsKey) ?? true;
        _loadMatches = prefs.getBool(_loadMatchesKey) ?? true;
        _marketingUpdates = prefs.getBool(_marketingUpdatesKey) ?? false;
        _darkMode = prefs.getBool(_darkModeKey) ??
            (ref.read(themeModeProvider) == ThemeMode.dark);
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

  Future<void> _updatePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).tr('logout')),
        content: Text(AppLocalizations.of(context).tr('logoutConfirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context).tr('logout')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _authService.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<void> _openVerification() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const VerificationDocumentsScreen(),
      ),
    );
    if (changed == true) {
      await _load();
    }
  }

  Widget _threadList(List<ThreadMessage> threads) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (threads.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppPalette.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppPalette.darkOutline : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(AppLocalizations.of(context).tr('noItemsYet')),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: threads.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final thread = threads[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CommentScreen(
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
            onComment: () {},
            onProfileTap: () {},
            panelController: null,
            userId: (_user?['id'] ?? '').toString(),
            showBidButton: false,
            showBidStatusWhenHidden: false,
          ),
        );
      },
    );
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
    final verification =
        VerificationAccess.normalizeStatus(user['verificationStatus']?.toString());
    final userType = (user['userType'] ?? 'Cargo').toString();
    final address = user['address']?.toString();
    final truckType = user['truckType']?.toString();
    final verificationNote = user['verificationNote']?.toString();
    final nationalIdPhoto = user['idPhoto']?.toString();
    final driverLicensePhoto = user['licenseNumberPhoto']?.toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? AppPalette.darkCard : Colors.white;
    final cardBorder = isDark ? AppPalette.darkOutline : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(localizations.tr('profile')),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          TextButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            label: Text(localizations.tr('logout')),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade400,
            ),
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
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (user['email'] ?? '').toString(),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white70,
                                  ),
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
                      _HeroChip(
                        label:
                            'Verification: ${VerificationAccess.statusTitle(verification)}',
                      ),
                      _HeroChip(
                        label:
                            '${localizations.tr('ratingLabel')}: ${ratingAvg.toStringAsFixed(1)} ($ratingCount)',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _ProfileMetricCard(
                          label: localizations.tr('myLoads'),
                          value: _myThreads.length.toString(),
                        ),
                      ),
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
              subtitle: 'Important profile information at a glance.',
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
                  _InfoRow(label: localizations.tr('truckTypeLabel'), value: truckType),
                _InfoRow(
                  label: 'Verification status',
                  value: VerificationAccess.statusTitle(verification),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _SectionTitle(
              title: 'Verification',
              subtitle: 'Upload the required documents and monitor admin review.',
            ),
            const SizedBox(height: 10),
            _InfoCard(
              color: cardColor,
              borderColor: cardBorder,
              children: [
                _VerificationSummaryCard(
                  userType: userType,
                  status: verification,
                  note: verificationNote,
                  nationalIdPhoto: nationalIdPhoto,
                  driverLicensePhoto: driverLicensePhoto,
                  onOpenVerification: _openVerification,
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _SectionTitle(
              title: 'Settings',
              subtitle: 'Notification and account preferences saved on this device.',
            ),
            const SizedBox(height: 10),
            _InfoCard(
              color: cardColor,
              borderColor: cardBorder,
              children: [
                _SettingsTile(
                  title: 'Dark mode',
                  subtitle: 'Use a high-contrast dark appearance across the app.',
                  value: _darkMode,
                  onChanged: (value) async {
                    setState(() => _darkMode = value);
                    await _updatePreference(_darkModeKey, value);
                    ref.read(themeModeProvider.notifier).state =
                        value ? ThemeMode.dark : ThemeMode.light;
                  },
                ),
                _SettingsTile(
                  title: 'Push notifications',
                  subtitle: 'General reminders and important account activity.',
                  value: _pushNotifications,
                  onChanged: (value) {
                    setState(() => _pushNotifications = value);
                    _updatePreference(_pushNotificationsKey, value);
                  },
                ),
                _SettingsTile(
                  title: 'Bid alerts',
                  subtitle: 'Updates when bids are placed, accepted, or changed.',
                  value: _bidAlerts,
                  onChanged: (value) {
                    setState(() => _bidAlerts = value);
                    _updatePreference(_bidAlertsKey, value);
                  },
                ),
                _SettingsTile(
                  title: 'Matching load suggestions',
                  subtitle: 'Recommendations for loads or drivers based on activity.',
                  value: _loadMatches,
                  onChanged: (value) {
                    setState(() => _loadMatches = value);
                    _updatePreference(_loadMatchesKey, value);
                  },
                ),
                _SettingsTile(
                  title: 'Product updates',
                  subtitle: 'Optional updates about improvements and new features.',
                  value: _marketingUpdates,
                  onChanged: (value) {
                    setState(() => _marketingUpdates = value);
                    _updatePreference(_marketingUpdatesKey, value);
                  },
                ),
                if (widget.onReplayTour != null) ...[
                  const Divider(height: 24),
                  _SettingsActionTile(
                    title: localizations.tr('tourReplayTitle'),
                    subtitle: localizations.tr('tourReplaySubtitle'),
                    icon: Icons.map_outlined,
                    onTap: widget.onReplayTour!,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            _SectionTitle(
              title: localizations.tr('myLoads'),
              subtitle: 'Your posted or owned shipments.',
            ),
            const SizedBox(height: 10),
            _threadList(_myThreads),
            const SizedBox(height: 18),
            _SectionTitle(
              title: localizations.tr('acceptedLoads'),
              subtitle: 'Loads currently awarded to you.',
            ),
            const SizedBox(height: 10),
            _threadList(_acceptedLoads),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppPalette.ink,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
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

  const _ProfileMetricCard({
    required this.label,
    required this.value,
  });

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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
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

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
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
                    color: AppPalette.ink,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.black54,
              height: 1.4,
            ),
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Future<void> Function() onTap;

  const _SettingsActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFDBEAFE),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: const Color(0xFF1D4ED8)),
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
      onTap: () async => onTap(),
    );
  }
}

class _VerificationSummaryCard extends StatelessWidget {
  final String userType;
  final String status;
  final String? note;
  final String? nationalIdPhoto;
  final String? driverLicensePhoto;
  final VoidCallback onOpenVerification;

  const _VerificationSummaryCard({
    required this.userType,
    required this.status,
    required this.note,
    required this.nationalIdPhoto,
    required this.driverLicensePhoto,
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
            color: statusColor.withAlpha(((isDark ? 0.24 : 0.10) * 255).round()),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                VerificationAccess.statusTitle(status),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                VerificationAccess.statusDescription(
                  userType: userType,
                  status: status,
                  note: note,
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Required documents',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        _DocumentStatusRow(
          title: 'National ID',
          isUploaded: (nationalIdPhoto ?? '').trim().isNotEmpty,
          imageSource: nationalIdPhoto,
        ),
        if (userType == 'Driver') ...[
          const SizedBox(height: 10),
          _DocumentStatusRow(
            title: 'Driver\'s license',
            isUploaded: (driverLicensePhoto ?? '').trim().isNotEmpty,
            imageSource: driverLicensePhoto,
          ),
        ],
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
  final String? imageSource;

  const _DocumentStatusRow({
    required this.title,
    required this.isUploaded,
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
          SizedBox(
            width: 56,
            height: 56,
            child: DocumentImage(source: imageSource, borderRadius: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  isUploaded ? 'Uploaded' : 'Missing',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isUploaded
                            ? const Color(0xFF16A34A)
                            : (isDark
                                ? AppPalette.darkTextSoft
                                : const Color(0xFF64748B)),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
