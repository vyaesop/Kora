import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kora/app_localizations.dart';
import 'package:kora/utils/app_theme.dart';
import 'package:kora/utils/backend_auth_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final Future<void> Function()? onReplayTour;

  const SettingsScreen({super.key, this.onReplayTour});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const String _darkModeKey = 'profile_dark_mode';

  final _authService = BackendAuthService();

  bool _loading = true;
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _darkMode =
          prefs.getBool(_darkModeKey) ??
          (ref.read(themeModeProvider) == ThemeMode.dark);
      _loading = false;
    });
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localizations = AppLocalizations.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SettingsSectionTitle(
              title: 'Appearance and alerts',
              subtitle: 'Preferences saved on this device.',
            ),
            const SizedBox(height: 10),
            _SettingsCard(
              child: _SettingsTile(
                title: 'Dark mode',
                subtitle: 'Use a calmer dark appearance across the app.',
                value: _darkMode,
                onChanged: (value) async {
                  setState(() => _darkMode = value);
                  await _updatePreference(_darkModeKey, value);
                  ref.read(themeModeProvider.notifier).state =
                      value ? ThemeMode.dark : ThemeMode.light;
                },
              ),
            ),
            if (widget.onReplayTour != null) ...[
              const SizedBox(height: 18),
              const _SettingsSectionTitle(
                title: 'Help',
                subtitle: 'Replay the guided walkthrough at any time.',
              ),
              const SizedBox(height: 10),
              _SettingsCard(
                child: _SettingsActionTile(
                  title: localizations.tr('tourReplayTitle'),
                  subtitle: localizations.tr('tourReplaySubtitle'),
                  icon: Icons.map_outlined,
                  onTap: widget.onReplayTour!,
                ),
              ),
            ],
            const SizedBox(height: 18),
            const _SettingsSectionTitle(
              title: 'Account',
              subtitle: 'Security and session controls.',
            ),
            const SizedBox(height: 10),
            _SettingsCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF402427)
                        : const Color(0xFFFDE8E8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.logout,
                    color: isDark
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFFB91C1C),
                  ),
                ),
                title: Text(
                  localizations.tr('logout'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Sign out of this device.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? AppPalette.darkTextSoft : Colors.black54,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _signOut,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SettingsSectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppPalette.darkOutline : const Color(0xFFE5E7EB),
        ),
      ),
      child: child,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: isDark ? AppPalette.darkTextSoft : Colors.black54,
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
          color: isDark ? const Color(0xFF1F3145) : const Color(0xFFE5EEF0),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: const Color(0xFF5B8C85)),
      ),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
