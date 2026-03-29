import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kora/app_localizations.dart';
import 'package:kora/screens/auth_check.dart';
import 'package:kora/screens/home.dart';
import 'package:kora/screens/login.dart';
import 'package:kora/screens/reset_password.dart';
import 'package:kora/utils/app_theme.dart';
import 'package:kora/utils/session_preferences.dart';

void main() {
  runApp(const ProviderScope(child: KoraApp()));
}

class KoraApp extends ConsumerStatefulWidget {
  const KoraApp({super.key});

  @override
  ConsumerState<KoraApp> createState() => _KoraAppState();
}

class _KoraAppState extends ConsumerState<KoraApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_restoreThemeMode);
    Future.microtask(_restoreLocale);
  }

  Future<void> _restoreThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(themeModePreferenceKey);
    if (!mounted) return;
    ref.read(themeModeProvider.notifier).state = AppTheme.parseThemeMode(raw);
  }

  Future<void> _restoreLocale() async {
    final locale = await SessionPreferences.getSavedLocale();
    if (!mounted || locale == null) return;
    ref.read(localeProvider.notifier).state = locale;
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'kora',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AuthCheckScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const Home(),
      },
      onGenerateRoute: (settings) {
        final name = settings.name ?? '';
        final parsed = Uri.tryParse(name);
        if (name.startsWith('/reset-password') ||
            (parsed != null &&
                parsed.scheme.isNotEmpty &&
                parsed.host == 'reset-password')) {
          final uri = parsed ?? Uri.parse(name);
          final email = uri.queryParameters['email'];
          final token = uri.queryParameters['token'];
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => ResetPasswordScreen(
              initialEmail: email,
              initialToken: token,
            ),
          );
        }

        if (name == '/' && Uri.base.path == '/reset-password') {
          final email = Uri.base.queryParameters['email'];
          final token = Uri.base.queryParameters['token'];
          return MaterialPageRoute(
            settings: const RouteSettings(name: '/reset-password'),
            builder: (_) => ResetPasswordScreen(
              initialEmail: email,
              initialToken: token,
            ),
          );
        }

        return null;
      },
    );
  }
}
