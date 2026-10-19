import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/models.dart';

/// Whether the reader asked to see the original text of a study (by study id).
final showOriginalProvider = StateProvider.autoDispose.family<bool, String>((ref, studyId) => false);

/// The study in the language the reader chose, or the original when they asked for it.
PublicStudy studyToShow(PublicStudy original, String language, {required bool showOriginal}) =>
    showOriginal ? original : original.localizedTo(language);

/// Says the page is an automatic translation (or that none exists) and offers the original.
class TranslationBanner extends ConsumerWidget {
  const TranslationBanner({super.key, required this.shown, required this.original, required this.language});

  final PublicStudy shown;
  final PublicStudy original;
  final String language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final showingOriginal = ref.watch(showOriginalProvider(original.id));
    final toggle = ref.read(showOriginalProvider(original.id).notifier);
    final missing = language != original.outputLanguage && original.localizedTo(language).translatedFrom == null;

    final String message;
    Widget? action;
    if (shown.translatedFrom != null) {
      message = l.translationNotice(l.languageNameEs);
      action = TextButton(onPressed: () => toggle.state = true, child: Text(l.showOriginal));
    } else if (showingOriginal && !missing) {
      message = '';
      action = TextButton(onPressed: () => toggle.state = false, child: Text(l.showTranslation));
    } else if (missing) {
      message = l.translationMissing;
    } else {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          if (message.isNotEmpty) Text(message, style: text.bodyMedium?.copyWith(fontSize: 13)),
          ?action,
        ],
      ),
    );
  }
}
