import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../data/progress.dart';
import '../../data/providers.dart';
import '../home/language_menu.dart';
import '../../l10n/locale.dart';
import '../today/part_tick.dart';
import '../today/today_page.dart' show tickWithFeedback;
import 'study_widgets.dart';
import 'translation_banner.dart';

/// One devotional day, laid out for reading on a phone.
class ReaderPage extends ConsumerWidget {
  const ReaderPage({super.key, required this.church, required this.slug, required this.dayNumber});

  final Church church;
  final String slug;
  final int dayNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final study = ref.watch(studyProvider((churchId: church.id, slug: slug)));
    final language = ref.watch(appLocaleProvider).languageCode;
    final backTo = '/c/${church.slug}/studies/$slug';
    return study.when(
      loading: () => SelahPage(
        backTo: backTo,
        actions: const [LanguageMenu(), SizedBox(width: 8)],
        maxWidth: 680,
        children: const [SkeletonList(hero: true, rows: 5)],
      ),
      error: (_, _) => SelahPage(
        backTo: backTo,
        actions: const [LanguageMenu(), SizedBox(width: 8)],
        children: [Text(l.loadError, style: text.bodyLarge)],
      ),
      data: (original) {
        final s = original == null
            ? null
            : studyToShow(original, language, showOriginal: ref.watch(showOriginalProvider(original.id)));
        final day = s?.days.where((d) => d.number == dayNumber).firstOrNull;
        if (original == null || s == null || day == null) {
          return SelahPage(
            backTo: backTo,
            actions: const [LanguageMenu(), SizedBox(width: 8)],
            children: [Text(l.studyNotFound, style: text.bodyLarge)],
          );
        }
        return _Day(church: church, study: s, original: original, language: language, day: day);
      },
    );
  }
}

class _Day extends ConsumerWidget {
  const _Day({
    required this.church,
    required this.study,
    required this.original,
    required this.language,
    required this.day,
  });

  final Church church;
  final PublicStudy study;
  final PublicStudy original;
  final String language;
  final DevotionalDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final progress = ref.watch(studyProgressProvider(original.id)).value;
    final ticked = progress?.days[day.number]?.parts ?? const <DayPart>{};
    Widget tick(DayPart part, String label) => PartTick(
          key: ValueKey('tick-${part.name}'),
          label: label,
          ticked: ticked.contains(part),
          onTap: () => tickWithFeedback(ref, original.id, day, part, ref.read(clockProvider)()),
        );
    // The reflection tick sits on the first of reflection, application and questions that the day has.
    final reflectionHolder = day.reflection != null ? 0 : day.application != null ? 1 : day.questions.isNotEmpty ? 2 : -1;
    Widget? reflectionTick(int i) => i == reflectionHolder ? tick(DayPart.reflection, l.reflection) : null;
    final total = study.days.length;
    final reading = serifReading(context);
    String dayPath(int n) => '/c/${church.slug}/studies/${study.slug}/day/$n';
    final scheme = Theme.of(context).colorScheme;
    // The same on-hero colour HeroCard draws its text in.
    final onHero = Theme.of(context).brightness == Brightness.light ? scheme.onPrimary : scheme.onSurface;
    return SelahPage(
      backTo: '/c/${church.slug}/studies/${study.slug}',
      actions: const [LanguageMenu(), SizedBox(width: 8)],
      maxWidth: 680,
      children: [
        TranslationBanner(shown: study, original: original, language: language),
        DayHero(
          tag: dayHeroTag(original.id, day.number),
          child: HeroCard(
            eyebrow: l.dayOfTotal(day.number, total),
            eyebrowAccessory: Row(
              children: [
                for (final d in study.days)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      d.number <= day.number || (progress?.isDone(d) ?? false) ? Icons.circle : Icons.circle_outlined,
                      size: 10,
                      color: onHero.withValues(alpha: d.number == day.number ? 1 : 0.6),
                    ),
                  ),
              ],
            ),
            title: day.title,
            quote: day.mainIdea,
          ),
        ),
        if (day.bibleReading != null) ...[
          const SizedBox(height: Space.l),
          Row(children: [
            Expanded(
              child: ExternalLink(
                icon: Icons.menu_book_outlined,
                label: l.readReference(day.bibleReading!, study.bibleVersionCode),
                uri: bibleReaderUrl(day.bibleReading!, study.bibleVersionCode),
              ),
            ),
            tick(DayPart.reading, l.bibleReading),
          ]),
          Text(l.externalReaderNote, style: text.bodyMedium?.copyWith(fontSize: 12)),
        ],
        if (day.reflection != null)
          ReadingSection(
            label: l.reflection,
            tick: reflectionTick(0),
            child: Text(day.reflection!, style: reading),
          ),
        if (day.application != null)
          ReadingSection(
            label: l.application,
            tick: reflectionTick(1),
            child: Text(day.application!, style: reading),
          ),
        if (day.questions.isNotEmpty)
          ReadingSection(
            label: l.questions,
            tick: reflectionTick(2),
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
            tick: tick(DayPart.prayer, l.prayer),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(day.prayer!, style: reading.copyWith(fontStyle: FontStyle.italic)),
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
        Row(
          children: [
            if (day.number > 1)
              TextButton.icon(
                onPressed: () => context.pushReplacement(dayPath(day.number - 1)),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(l.previousDay),
              ),
            const Spacer(),
            if (day.number < total)
              FilledButton(onPressed: () => context.pushReplacement(dayPath(day.number + 1)), child: Text(l.nextDay)),
          ],
        ),
      ],
    );
  }
}
