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
  const ReaderPage({super.key, required this.church, required this.slug, required this.dayNumber, this.initialStudy});

  final Church church;
  final String slug;
  final int dayNumber;

  /// The study the opener already has; shown while [studyProvider] loads so the hero header is there on the first frame.
  final PublicStudy? initialStudy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final study = ref.watch(studyProvider((churchId: church.id, slug: slug)));
    final language = ref.watch(appLocaleProvider).languageCode;
    final backTo = '/c/${church.slug}/studies/$slug';
    Widget loaded(PublicStudy? original) {
      final s = original == null
          ? null
          : studyToShow(original, language, showOriginal: ref.watch(showOriginalProvider(original.id)));
      final day = s?.days.where((d) => d.number == dayNumber).firstOrNull;
      if (original == null || s == null || day == null) {
        return SelahPage(
          backTo: backTo,
          actions: const [LanguageMenu(pageAction: true), SizedBox(width: 8)],
          children: [Text(l.studyNotFound, style: text.bodyLarge)],
        );
      }
      return _Day(church: church, study: s, original: original, language: language, day: day);
    }

    // While the fetch runs, the study the opener passed in stands in, so the hero header is on screen for the flight.
    final seed = initialStudy?.slug == slug ? initialStudy : null;
    if (!study.hasValue && !study.hasError && seed != null) return loaded(seed);
    return study.when(
      loading: () => SelahPage(
        backTo: backTo,
        actions: const [LanguageMenu(pageAction: true), SizedBox(width: 8)],
        maxWidth: 680,
        children: const [SkeletonList(hero: true, rows: 5)],
      ),
      error: (_, _) => SelahPage(
        backTo: backTo,
        actions: const [LanguageMenu(pageAction: true), SizedBox(width: 8)],
        children: [Text(l.loadError, style: text.bodyLarge)],
      ),
      data: loaded,
    );
  }
}

/// Swaps the day in place. Neglected, so on web the browser's back leaves the reader like the in-app back, instead of
/// walking through each day read.
void _goToDay(BuildContext context, String path, PublicStudy original) =>
    Router.neglect(context, () => context.pushReplacement(path, extra: original));

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
    final content = <Widget>[
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
        Text(l.externalReaderNote, style: text.bodySmall),
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
              Text(l.prayerNote, style: text.bodySmall),
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
      // Wraps so the two buttons stack at large text sizes instead of overflowing.
      Wrap(
        alignment: day.number > 1 ? WrapAlignment.spaceBetween : WrapAlignment.end,
        spacing: Space.m,
        runSpacing: Space.s,
        children: [
          if (day.number > 1)
            TextButton.icon(
              onPressed: () => _goToDay(context, dayPath(day.number - 1), original),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(l.previousDay),
            ),
          if (day.number < total)
            FilledButton(onPressed: () => _goToDay(context, dayPath(day.number + 1), original), child: Text(l.nextDay)),
        ],
      ),
    ];
    if (siteLayout(context)) {
      // The website layout: the text at reading width, the study's days beside it.
      return SelahPage(
        backTo: '/c/${church.slug}/studies/${study.slug}',
        actions: const [LanguageMenu(pageAction: true), SizedBox(width: 8)],
        maxWidth: Layout.readingMeasure + Space.xxl + 280,
        children: [
          TwoColumn(
            sideWidth: 280,
            main: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: content),
            side: _DayList(
              study: study,
              current: day.number,
              onOpen: (n) => _goToDay(context, dayPath(n), original),
            ),
          ),
        ],
      );
    }
    return SelahPage(
      backTo: '/c/${church.slug}/studies/${study.slug}',
      actions: const [LanguageMenu(pageAction: true), SizedBox(width: 8)],
      maxWidth: 680,
      children: content,
    );
  }
}

/// The study's days beside the reader on a wide page. The day being read is marked and isn't a link.
class _DayList extends StatelessWidget {
  const _DayList({required this.study, required this.current, required this.onOpen});

  final PublicStudy study;
  final int current;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final total = study.days.length;
    String label(DevotionalDay d) => '${l.dayOfTotal(d.number, total)} · ${d.title}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Eyebrow(study.title),
        const SizedBox(height: Space.m),
        for (final d in study.days)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: d.number == current
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
                    decoration: BoxDecoration(
                      color: context.tones.surface,
                      borderRadius: BorderRadius.circular(Radii.row),
                      border: Border(left: BorderSide(color: scheme.primary, width: 3)),
                    ),
                    child: Text(label(d), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.primary)),
                  )
                : SelahRow(label: label(d), onOpen: () => onOpen(d.number)),
          ),
      ],
    );
  }
}
