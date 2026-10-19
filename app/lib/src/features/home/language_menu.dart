import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../l10n/locale.dart';

/// Each language is named in itself, whatever the current interface language.
const _languageNames = {'es': 'Español', 'en': 'English', 'pt': 'Português'};

class LanguageMenu extends ConsumerWidget {
  const LanguageMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appLocaleProvider).languageCode;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.translate),
      tooltip: AppLocalizations.of(context)!.language,
      initialValue: current,
      onSelected: (language) =>
          ref.read(appLocaleProvider.notifier).set(language),
      itemBuilder: (_) => [
        for (final language in supportedLanguages)
          PopupMenuItem(
            value: language,
            child: Text(_languageNames[language]!),
          ),
      ],
    );
  }
}
