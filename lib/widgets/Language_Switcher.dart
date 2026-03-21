import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_localizations.dart';

class LanguageSwitcher extends ConsumerWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider) ?? Localizations.localeOf(context);

    const languageLabels = {
      'en': 'English',
      'am': 'Amharic',
      'om': 'Oromiffa',
    };

    final localizations = AppLocalizations.of(context);
    return PopupMenuButton<Locale>(
      tooltip: localizations.tr('language'),
      onSelected: (value) => ref.read(localeProvider.notifier).state = value,
      itemBuilder: (context) => AppLocalizations.supportedLocales
          .map(
            (supported) => PopupMenuItem<Locale>(
              value: supported,
              child: Text(languageLabels[supported.languageCode] ??
                  supported.languageCode.toUpperCase()),
            ),
          )
          .toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.language, size: 18),
          const SizedBox(width: 6),
          Text(
            (languageLabels[locale.languageCode] ?? locale.languageCode)
                .toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

