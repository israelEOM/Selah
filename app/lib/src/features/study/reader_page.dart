import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/design/art.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../data/progress.dart';
import '../../data/providers.dart';
import '../home/language_menu.dart';
import '../../l10n/locale.dart';
import '../today/today_page.dart' show tickWithFeedback;
import '../today/today_selection.dart';
import '../today/week_rings.dart' show PartRing;
import 'study_widgets.dart';
import 'tick_dock.dart';
import 'translation_banner.dart';

/// What the opener hands the reader as the route's `extra`: the study it already has, whether it is Today, and the
/// past date Today was showing, if any.
class ReaderEntry {
  const ReaderEntry({required this.study, this.fromToday = false, this.on});

  final PublicStudy study;
  final bool fromToday;

  /// The past date (`yyyy-MM-dd`) picked on Today; ticks in the reader are recorded on it.
  final String? on;

  /// The entry in a route's `extra`, which may also be a bare [PublicStudy] (from the study page) or nothing (a link).
  static ReaderEntry? from(Object? extra) => switch (extra) {
        final ReaderEntry entry => entry,
        final PublicStudy study => ReaderEntry(study: study),
        _ => null,
      };
}

/// One devotional day, laid out for reading on a phone.
class ReaderPage extends ConsumerWidget {
  const ReaderPage({
    super.key,
    required this.church,
    required this.slug,
    required this.dayNumber,
    this.initialStudy,
    this.fromToday = false,
    this.on,
  });

  final Church church;
  final String slug;
  final int dayNumber;

  /// The study the opener already has; shown while [studyProvider] loads so the hero header is there on the first frame.
  final PublicStudy? initialStudy;

  /// Opened from Today: "back to Today" returns to it as it was, on the date it showed.
  final bool fromToday;

  /// The past date Today was showing when it opened the reader; ticks land on it. Null ticks today.
  final String? on;

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
      return _Day(
        church: church,
        study: s,
        original: original,
        language: language,
        day: day,
        fromToday: fromToday,
        on: on,
      );
    }

    // While the fetch runs, the study the opener passed in stands in, so the hero header is on screen for the flight.
    final seed = initialStudy?.slug == slug ? initialStudy : null;
    // One switcher for both ways in, so the stand-in and the fetched study are the same `_Day` and nothing fades.
    final Widget page;
    if (!study.hasValue && !study.hasError && seed != null) {
      page = loaded(seed);
    } else {
      page = study.when(
        loading: () => SelahPage(
          key: const ValueKey('loading'),
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
    return ContentSwitcher(child: page);
  }
}

/// Swaps the day in place. Neglected, so on web the browser's back leaves the reader like the in-app back, instead of
/// walking through each day read. A reader opened from Today stays so, but another day's ticks count today: only the
/// day Today showed belongs to its past date.
void _goToDay(BuildContext context, String path, PublicStudy original, {required bool fromToday}) => Router.neglect(
      context,
      () => context.pushReplacement(path, extra: ReaderEntry(study: original, fromToday: fromToday)),
    );

class _Day extends ConsumerStatefulWidget {
  const _Day({
    required this.church,
    required this.study,
    required this.original,
    required this.language,
    required this.day,
    required this.fromToday,
    required this.on,
  });

  final Church church;
  final PublicStudy study;
  final PublicStudy original;
  final String language;
  final DevotionalDay day;
  final bool fromToday;
  final String? on;

  @override
  ConsumerState<_Day> createState() => _DayState();
}

class _DayState extends ConsumerState<_Day> {
  /// The top of each part's first section, to tell which one is being read.
  final _sections = {for (final part in DayPart.values) part: GlobalKey(debugLabel: 'section-${part.name}')};

  /// Whether a tick from the bar finished the day during this visit. Only then does "back to Today" play moment A;
  /// re-opening a day finished earlier shows the pill but doesn't replay it.
  bool _finishedHere = false;

  /// The part being read: its chip is the wide one in the tick bar.
  late DayPart _current = partsFor(widget.day).first;

  @override
  void didUpdateWidget(_Day old) {
    super.didUpdateWidget(old);
    if (widget.day.number != old.day.number) {
      _current = partsFor(widget.day).first;
      _finishedHere = false;
    }
  }

  /// Whether a check of the current part is already waiting for the next frame.
  bool _spyQueued = false;

  /// On each scroll, after the frame lays out the new offset (a single mouse-wheel step sends one notification, and
  /// the sections only move at layout): the last part whose section starts above 45% of the screen, or the last part
  /// once the page is scrolled to its end (the final section can be too short to reach that line).
  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical || _spyQueued) return false;
    _spyQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _spyQueued = false;
      if (!mounted) return;
      final parts = partsFor(widget.day);
      final scrollable = _sections[parts.first]!.currentContext;
      final metrics = scrollable == null ? null : Scrollable.maybeOf(scrollable)?.position;
      var current = parts.first;
      if (metrics != null && metrics.maxScrollExtent > 0 && metrics.extentAfter < 1) {
        current = parts.last;
      } else {
        final line = MediaQuery.sizeOf(context).height * 0.45;
        for (final part in parts) {
          final box = _sections[part]!.currentContext?.findRenderObject() as RenderBox?;
          if (box != null && box.attached && box.localToGlobal(Offset.zero).dy <= line) current = part;
        }
      }
      if (current != _current) setState(() => _current = current);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
    return false;
  }

  Future<bool> _tick(DayPart part, {bool announce = true}) => tickWithFeedback(
        ref,
        widget.original.id,
        widget.day,
        part,
        ref.read(clockProvider)(),
        on: widget.on,
        announce: announce,
      );

  /// Back to Today, which plays moment A for this day if it was finished here. Opened from Today, it returns to Today
  /// as it was, on the date it showed; from anywhere else it goes to Today on today.
  void _backToToday() {
    final back = widget.fromToday && context.canPop();
    // Picked first: changing the date clears a just-finished mark.
    if (!back) ref.read(selectedDateProvider.notifier).select(null);
    if (_finishedHere) {
      ref.read(justFinishedProvider.notifier).set((studyId: widget.original.id, day: widget.day.number));
    }
    if (back) {
      context.pop();
    } else {
      context.go('/today');
    }
  }

  @override
  Widget build(BuildContext context) {
    final church = widget.church;
    final study = widget.study;
    final original = widget.original;
    final language = widget.language;
    final day = widget.day;
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final progress = ref.watch(studyProgressProvider(original.id)).value;
    final ticked = progress?.days[day.number]?.parts ?? const <DayPart>{};
    // Every layout ticks from the floating bar; the website layout floats it under the text column.
    final site = siteLayout(context);
    // The reflection part starts at the first of reflection, application and questions that the day has.
    final reflectionHolder = day.reflection != null ? 0 : day.application != null ? 1 : day.questions.isNotEmpty ? 2 : -1;
    Key? reflectionKey(int i) => i == reflectionHolder ? _sections[DayPart.reflection] : null;
    final total = study.days.length;
    final reading = serifReading(context);
    String dayPath(int n) => '/c/${church.slug}/studies/${study.slug}/day/$n';
    final onHero = heroForeground(context);
    final content = <Widget>[
      TranslationBanner(shown: study, original: original, language: language),
      // Still while the page arrives, so the card from Today lands where it belongs.
      NoArrive(
        child: DayHero(
          tag: dayHeroTag(original.id, day.number),
          child: HeroCard(
            // The eyebrow with the day's ring beside it.
            eyebrowAccessory: Row(
              children: [
                Flexible(
                  child: Text(
                    l.dayOfTotal(day.number, total).toUpperCase(),
                    style: text.labelSmall?.copyWith(color: onHero.withValues(alpha: 0.8)),
                  ),
                ),
                const SizedBox(width: Space.s),
                PartRing(parts: ticked, complete: progress?.isDone(day) ?? false, size: 22, onHero: true),
              ],
            ),
            title: day.title,
            quote: day.mainIdea,
            art: SelahArt(artKey: day.artKey, seed: '${original.id}-${day.number}', radius: 0, placeholder: false),
          ),
        ),
      ),
      if (day.bibleReading != null) ...[
        const SizedBox(height: Space.l),
        Column(
          key: _sections[DayPart.reading],
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExternalLink(
              icon: Icons.menu_book_outlined,
              label: l.readReference(day.bibleReading!, study.bibleVersionCode),
              uri: bibleReaderUrl(day.bibleReading!, study.bibleVersionCode),
            ),
            Text(l.externalReaderNote, style: text.bodySmall),
          ],
        ),
      ],
      if (day.reflection != null)
        ReadingSection(
          key: reflectionKey(0),
          label: l.reflection,
          part: DayPart.reflection,
          child: Text(day.reflection!, style: reading),
        ),
      if (day.application != null)
        ReadingSection(
          key: reflectionKey(1),
          label: l.application,
          part: DayPart.reflection,
          child: Text(day.application!, style: reading),
        ),
      if (day.questions.isNotEmpty)
        ReadingSection(
          key: reflectionKey(2),
          label: l.questions,
          part: DayPart.reflection,
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
          key: _sections[DayPart.prayer],
          label: l.prayer,
          part: DayPart.prayer,
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
              onPressed: () => _goToDay(context, dayPath(day.number - 1), original, fromToday: widget.fromToday),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(l.previousDay),
            ),
          if (day.number < total)
            FilledButton(
              onPressed: () => _goToDay(context, dayPath(day.number + 1), original, fromToday: widget.fromToday),
              child: Text(l.nextDay),
            ),
        ],
      ),
    ];
    const sideWidth = 280.0;
    const siteWidth = Layout.readingMeasure + Space.xxl + sideWidth;
    final page = site
        // The website layout: the text at reading width, the study's days beside it.
        ? SelahPage(
            backTo: '/c/${church.slug}/studies/${study.slug}',
            actions: const [LanguageMenu(pageAction: true), SizedBox(width: 8)],
            maxWidth: siteWidth,
            children: [
              TwoColumn(
                sideWidth: sideWidth,
                main: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...content,
                    const SizedBox(height: TickDock.clearance),
                  ],
                ),
                side: _DayList(
                  study: study,
                  current: day.number,
                  onOpen: (n) => _goToDay(context, dayPath(n), original, fromToday: widget.fromToday),
                ),
              ),
            ],
          )
        : SelahPage(
            backTo: '/c/${church.slug}/studies/${study.slug}',
            actions: const [LanguageMenu(pageAction: true), SizedBox(width: 8)],
            maxWidth: 680,
            children: [
              ...content,
              const SizedBox(height: TickDock.clearance),
            ],
          );
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // On the website the bar spans the text column, matching SelahPage's centred site width and TwoColumn.
          final siteSide = max(Space.xl, (constraints.maxWidth - min(siteWidth, Layout.maxContent)) / 2);
          final siteMain = constraints.maxWidth - 2 * siteSide - Space.xxl - sideWidth;
          return Stack(
            children: [
              page,
              Positioned(
                left: site ? siteSide : TickDock.sideInset,
                right: site ? constraints.maxWidth - siteSide - siteMain : TickDock.sideInset,
                bottom: TickDock.bottomInset + MediaQuery.paddingOf(context).bottom,
                child: TickDock(
                  parts: partsFor(day),
                  ticked: ticked,
                  current: _current,
                  onTick: (part) {
                    // Decided before the tick, not from its result: that only arrives after the success haptic.
                    final finishes =
                        !ticked.contains(part) && partsFor(day).every((p) => p == part || ticked.contains(p));
                    if (finishes) _finishedHere = true;
                    _tick(part, announce: false);
                  },
                  onComplete: _backToToday,
                ),
              ),
            ],
          );
        },
      ),
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
