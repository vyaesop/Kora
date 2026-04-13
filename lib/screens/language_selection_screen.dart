import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kora/app_localizations.dart';
import 'package:kora/screens/login.dart';
import 'package:kora/screens/phone_verification_screen.dart';
import 'package:kora/utils/app_theme.dart';
import 'package:kora/utils/session_preferences.dart';

class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  ConsumerState<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState
    extends ConsumerState<LanguageSelectionScreen> {
  Locale _selectedLocale = const Locale('en');

  static const Map<String, Map<String, String>> _languageMeta = {
    'en': {
      'label': 'English',
      'caption': 'Use the app in English',
    },
    'am': {
      'label': 'Amharic',
      'caption': 'በአማርኛ ይቀጥሉ',
    },
    'om': {
      'label': 'Oromiffa',
      'caption': 'Afaan Oromootiin itti fufi',
    },
  };

  Future<void> _saveLanguageAndOpen(Widget screen) async {
    ref.read(localeProvider.notifier).state = _selectedLocale;
    await SessionPreferences.saveLocale(_selectedLocale);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppPalette.heroGradient,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.12 * 255).round()),
                        blurRadius: 28,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose your language',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Set the language first, then continue into sign up or sign in. You can still change it later from the auth screens.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                              height: 1.45,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ...AppLocalizations.supportedLocales.map((locale) {
                  final selected = locale.languageCode == _selectedLocale.languageCode;
                  final meta = _languageMeta[locale.languageCode] ?? const {};
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => setState(() => _selectedLocale = locale),
                      child: Ink(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark ? AppPalette.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: selected
                                ? AppPalette.accent
                                : (isDark
                                    ? AppPalette.darkOutline
                                    : const Color(0xFFE5E7EB)),
                            width: selected ? 1.4 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppPalette.accent.withAlpha((0.18 * 255).round())
                                    : (isDark
                                        ? AppPalette.darkSurfaceRaised
                                        : const Color(0xFFF8FAFC)),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.language_rounded,
                                color: selected
                                    ? AppPalette.accent
                                    : AppPalette.accentWarm,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    meta['label'] ?? locale.languageCode.toUpperCase(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    meta['caption'] ?? '',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: isDark
                                              ? AppPalette.darkTextSoft
                                              : Colors.black54,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: selected
                                  ? AppPalette.accent
                                  : (isDark
                                      ? AppPalette.darkTextSoft
                                      : const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _saveLanguageAndOpen(
                    const PhoneVerificationScreen(showBackToLogin: false),
                  ),
                  child: const Text('Continue to sign up'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => _saveLanguageAndOpen(const LoginScreen()),
                  child: const Text('I already have an account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
