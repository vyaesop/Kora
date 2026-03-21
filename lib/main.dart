import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kora/app_localizations.dart';
import 'package:kora/screens/auth_check.dart';
import 'package:kora/screens/home.dart';
import 'package:kora/screens/login.dart';
import 'package:kora/screens/reset_password.dart';
import 'package:kora/utils/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: KoraApp()));
}

class KoraApp extends ConsumerWidget {
  const KoraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'kora',
      theme: AppTheme.light,
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

        // Web deep link support
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


