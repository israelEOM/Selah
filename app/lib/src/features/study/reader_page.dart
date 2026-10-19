import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../data/providers.dart';
import '../home/language_menu.dart';
import '../../l10n/locale.dart';
import 'study_widgets.dart';
import 'translation_banner.dart';

/// One devotional day, laid out for reading on a phone.
class ReaderPage extends ConsumerWidget {
  const ReaderPage({super.key, required this.slug, required this.dayNumber});

  final String slug;
  final int dayNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final study = ref.watch(studyProvider(slug));
    final language = ref.watch(appLocaleProvider).languageCode;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l.backToStudy,
          onPressed: () => context.go('/studies/$slug'),
        ),
        actions: const [LanguageMenu(), SizedBox(width: 8)],
      ),
      body: study.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => PageBody(children: [Text(l.loadError, style: text.bodyLarge)]),
        data: (original) {
          final s = original == null
              ? null
              : studyToShow(original, language, showOriginal: ref.watch(showOriginalProvider(original.id)));
          final day = s?.days.where((d) => d.number == dayNumber).firstOrNull;
          if (original == null || s == null || day == null) {
            return PageBody(children: [Text(l.studyNotFound, style: text.bodyLarge)]);
          }
          return _Day(study: s, original: original, language: language, day: day);
        },
      ),
    );
  }
}

class _Day extends ConsumerWidget {
  const _Day({required this.study, required this.original, required this.language, required this.day});

  final PublicStudy study;
  final PublicStudy original;
  final String language;
  final DevotionalDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final read = ref.watch(readDaysProvider(study.id)).value ?? const <int>{};
    final total = study.days.length;
    final reading = text.bodyLarge?.copyWith(fontSize: 18, height: 1.7);
    String dayPath(int n) => '/studies/${study.slug}/day/$n';
    return PageBody(
      maxWidth: 680,
      children: [
        TranslationBanner(shown: study, original: original, language: language),
        Eyebrow(l.dayOfTotal(day.number, total)),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final d in study.days)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  d.number <= day.number || read.contains(d.number) ? Icons.circle : Icons.circle_outlined,
                  size: 10,
                  color: d.number == day.number ? SelahColors.gold : SelahColors.ink.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Text(day.title, style: text.displaySmall?.copyWith(fontSize: 34)),
        if (day.bibleReading != null) ...[
          const SizedBox(height: 14),
          ExternalLink(
            icon: Icons.menu_book_outlined,
            label: l.readReference(day.bibleReading!, study.bibleVersionCode),
            uri: bibleReaderUrl(day.bibleReading!, study.bibleVersionCode),
          ),
          Text(l.externalReaderNote, style: text.bodyMedium?.copyWith(fontSize: 12)),
        ],
        if (day.mainIdea != null) ...[
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.only(left: 16),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: SelahColors.gold, width: 2)),
            ),
            child: Text(day.mainIdea!, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w500)),
          ),
        ],
        if (day.reflection != null)
          ReadingSection(
            label: l.reflection,
            child: Text(day.reflection!, style: reading),
          ),
        if (day.application != null)
          ReadingSection(
            label: l.application,
            child: Text(day.application!, style: reading),
          ),
        if (day.questions.isNotEmpty)
          ReadingSection(
            label: l.questions,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, q) in day.questions.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text('${i + 1}. $q', style: reading),
                  ),
              ],
            ),
          ),
        if (day.prayer != null)
          ReadingSection(
            label: l.prayer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(day.prayer!, style: reading?.copyWith(fontStyle: FontStyle.italic)),
                const SizedBox(height: 8),
                Text(l.prayerNote, style: text.bodyMedium?.copyWith(fontSize: 12)),
              ],
            ),
          ),
        if (day.startSeconds != null) ...[
          const SizedBox(height: 28),
          ExternalLink(
            label: '${l.watchThisPart} (${clock(day.startSeconds)})',
            uri: youtubeAt(study.sermon.videoId, day.startSeconds),
          ),
        ],
        const SizedBox(height: 28),
        read.contains(day.number)
            ? Row(
                children: [
                  const Icon(Icons.check_circle, color: SelahColors.ink),
                  const SizedBox(width: 8),
                  Text(l.markedRead, style: text.bodyLarge),
                ],
              )
            : OutlinedButton(onPressed: () => markDayRead(ref, study.id, day.number), child: Text(l.markRead)),
        const SizedBox(height: 28),
        Row(
          children: [
            if (day.number > 1)
              TextButton.icon(
                onPressed: () => context.go(dayPath(day.number - 1)),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(l.previousDay),
              ),
            const Spacer(),
            if (day.number < total)
              FilledButton(onPressed: () => context.go(dayPath(day.number + 1)), child: Text(l.nextDay)),
          ],
        ),
      ],
    );
  }
}
