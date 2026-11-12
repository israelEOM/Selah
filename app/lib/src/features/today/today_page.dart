import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/design/art.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../data/current_church.dart';
import '../../data/progress.dart';
import '../../data/providers.dart';
import '../../l10n/locale.dart';
import '../events/events_page.dart';
import '../home/church_picker_page.dart';
import '../study/reader_page.dart' show ReaderEntry;
import '../study/translation_banner.dart';
import 'finish_moment.dart';
import 'part_row.dart';
import 'part_style.dart';
import 'today_refresh.dart';
import 'today_selection.dart';
import 'today_state.dart';
import 'week_rings.dart';

/// Ticks [part], dated [on] (`yyyy-MM-dd`) or today. When that finishes the day it plays the success haptic, returns
/// true and, if [announce], marks the day just finished so Today plays moment A. Today and the reader both tick
/// through this; the phone reader announces only when its "back to Today" pill is tapped.
Future<bool> tickWithFeedback(
  WidgetRef ref,
  String progressId,
  DevotionalDay day,
  DayPart part,
  DateTime now, {
  String? on,
  bool announce = true,
}) async {
  final progress = await togglePart(progressId, day, part, now, on: on);
  // A toggle can only finish the day by adding its last part, so done now means it just became done.
  final done = progress.isDone(day);
  // Marked before the reload, so the first build that shows the finished day already knows to play moment A.
  if (done && announce) ref.read(justFinishedProvider.notifier).set((studyId: progressId, day: day.number));
  ref.invalidate(studyProgressProvider(progressId));
  ref.invalidate(ticksByDateProvider);
  if (done) await SelahHaptics.success();
  return done;
}

/// The Hoy tab: today's part of the church's newest study, or the church list when none is chosen yet.
class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    // The skeleton crossfades into the day (or the church list) once the church is known.
    return ContentSwitcher(
      child: ref.watch(currentChurchProvider).when(
          loading: () => SelahPage(
            key: const ValueKey('loading'),
            title: l.tabToday,
            children: const [SkeletonList(hero: true, rows: 3)],
          ),
          error: (_, _) => SelahPage(
            title: l.tabToday,
            children: [_LoadError(onRetry: () => ref.invalidate(currentChurchProvider))],
          ),
          data: (church) => church == null
              ? SelahPage(
                  title: l.pickChurch,
                  onRefresh: () => refreshChurches(ref),
                  lazy: true,
                  children: churchListChildren(context, ref),
                )
              : TodayRefresher(churchId: church.id, child: _Today(church: church)),
      ),
    );
  }
}

class _Today extends ConsumerWidget {
  const _Today({required this.church});

  final Church church;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    // Rebuilt with a fresh `now` on resume, at midnight and on pull to refresh.
    ref.watch(todayRefreshProvider);
    final now = ref.watch(clockProvider)();
    final language = ref.watch(appLocaleProvider).languageCode;
    final ticks = ref.watch(ticksByDateProvider).value ?? const <String, DateTicks>{};
    final todayKey = localDate(now);
    final picked = ref.watch(selectedDateProvider);
    // A past date picked in the week; null when Today shows today.
    final past = picked != null && picked.compareTo(todayKey) < 0 ? picked : null;
    final title = past == null
        ? l.tabToday
        : past == localDate(DateTime(now.year, now.month, now.day - 1))
            ? l.todayYesterday
            : _capitalised(DateFormat.EEEE(l.localeName).format(DateTime.parse(past)));
    final eyebrowStyle = text.labelMedium?.copyWith(color: context.tones.muted, fontWeight: FontWeight.w600, letterSpacing: 0.6);
    final dateLine = Text.rich(
      TextSpan(children: [
        TextSpan(text: DateFormat.MMMMEEEEd(l.localeName).format(now).toUpperCase()),
        const TextSpan(text: '  ·  '),
        TextSpan(text: church.name),
      ]),
      style: eyebrowStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final site = siteLayout(context);
    final header = [
      // The app layout pins the date line under the title instead.
      if (site) ...[dateLine, const SizedBox(height: Space.l)],
      WeekRings(
        ticks: ticks,
        now: now,
        selected: past ?? todayKey,
        onSelect: (date) => ref.read(selectedDateProvider.notifier).select(date == todayKey ? null : date),
      ),
      const SizedBox(height: Space.xl),
    ];
    Widget page(List<Widget> children, {bool skeleton = false}) {
      // The day's content slides to the side when another date is picked, and crossfades in from its skeleton.
      final content = _DaySwitch(
        date: past ?? todayKey,
        child: Column(
          key: ValueKey(past ?? todayKey),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ContentSwitcher(
              child: Column(
                key: ValueKey(skeleton ? 'skeleton' : 'day'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ],
        ),
      );
      if (!site) {
        return SelahPage(
          title: title,
          subtitle: dateLine,
          onRefresh: () => refreshToday(ref, church.id),
          // The part rows stagger in on their own, and the hero card must sit still for its flight to the reader.
          arrive: false,
          children: [...header, content],
        );
      }
      // The website layout: the day on the left; the date, the week and what's coming up on the right.
      final events = (ref.watch(upcomingEventsProvider(church.id)).value ?? const <ChurchEvent>[])
          .where((e) => e.endsAt.isAfter(now))
          .take(3)
          .toList();
      return SelahPage(
        title: title,
        wide: true,
        children: [
          TwoColumn(
            main: content,
            side: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...header,
                if (events.isNotEmpty) ...[
                  const SizedBox(height: Space.section - Space.xl),
                  Eyebrow(l.eventsLater),
                  const SizedBox(height: Space.m),
                  for (final event in events)
                    Padding(padding: const EdgeInsets.only(bottom: Space.s), child: EventRow(event: event)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(onPressed: () => context.go('/c/${church.slug}/events'), child: Text(l.tabEvents)),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }
    final loading = page(const [SkeletonList(hero: true, rows: 3)], skeleton: true);
    return ref.watch(newestStudyProvider(church.id)).when(
          loading: () => loading,
          error: (_, _) => page([_LoadError(onRetry: () => ref.invalidate(newestStudyProvider(church.id)))]),
          data: (original) {
            if (original == null) {
              return page([
                const Center(
                  child: SelahArt(
                    artKey: 'scene-empty-studies',
                    fixed: true,
                    seed: 'empty-studies',
                    width: double.infinity,
                    height: 180,
                  ),
                ),
                const SizedBox(height: Space.l),
                Text(l.noStudiesYetToday, style: text.bodyLarge),
                const SizedBox(height: Space.l),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(onPressed: () => context.go('/c/${church.slug}'), child: Text(l.goToStudies)),
                ),
              ]);
            }
            return ref.watch(studyProgressProvider(original.id)).when(
                  loading: () => loading,
                  error: (_, _) => page([_LoadError(onRetry: () => ref.invalidate(studyProgressProvider(original.id)))]),
                  data: (progress) {
                    final study = studyToShow(original, language, showOriginal: ref.watch(showOriginalProvider(original.id)));
                    final state = todayFor(study: study, progress: progress, now: now);
                    final summary = Padding(
                      padding: const EdgeInsets.only(top: Space.xl),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed: () => context.push('/c/${church.slug}/studies/${study.slug}'),
                          child: Text(l.sermonSummaryButton),
                        ),
                      ),
                    );
                    final day = dayForSelection(study: study, progress: progress, ticks: ticks, date: past, now: now);
                    if (day == null) {
                      return page(switch (state) {
                        AllDone(:final passage, :final takeaway) => [
                            Text(l.meditateToday, style: text.headlineMedium),
                            if (passage != null || takeaway != null) ...[
                              const SizedBox(height: Space.l),
                              HeroCard(
                                eyebrow: passage == null ? null : '${l.todayMainPassage} · $passage',
                                footer: takeaway == null
                                    ? null
                                    : SettleWords(
                                        text: takeaway,
                                        style: serifQuote(context).copyWith(color: heroForeground(context)),
                                      ),
                              ),
                            ],
                            if (passage != null) ...[
                              const SizedBox(height: Space.l),
                              SelahRow(
                                label: l.readPassage(passage),
                                onOpen: () => _openBible(passage, study.bibleVersionCode),
                              ),
                            ],
                            summary,
                          ],
                        _ => const [],
                      });
                    }
                    final done = progress.isDone(day);
                    final moment = _momentA(ref, original, day, done);
                    final next = past == null && state is DoneForToday ? state.next : null;
                    return page([
                      ..._devotional(context, ref, study, original, day, progress, on: past, moment: moment),
                      if (past != null && !done) ...[
                        const SizedBox(height: Space.s),
                        Text(l.pastDayNotTooLate, style: text.bodyLarge?.copyWith(color: context.tones.muted)),
                      ],
                      if (done) ...[
                        const SizedBox(height: Space.l),
                        FinishLine(past: past != null, animate: moment),
                      ],
                      if (next != null)
                        Padding(
                          padding: const EdgeInsets.only(top: Space.s),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => context.push(
                                _dayPath(study, next.number),
                                extra: ReaderEntry(study: original, fromToday: true),
                              ),
                              child: Text(l.readNext),
                            ),
                          ),
                        ),
                      summary,
                    ]);
                  },
                );
          },
        );
  }

  /// Whether moment A should play for [day] now: it was just finished by a tick. Today clears the mark once the moment
  /// has started, so it plays once; the widgets let a started moment run to its end.
  bool _momentA(WidgetRef ref, PublicStudy original, DevotionalDay day, bool done) {
    final just = ref.watch(justFinishedProvider);
    final play = done && just == (studyId: original.id, day: day.number);
    if (play) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(justFinishedProvider) == just) ref.read(justFinishedProvider.notifier).clear();
      });
    }
    return play;
  }

  String _dayPath(PublicStudy study, int n) => '/c/${church.slug}/studies/${study.slug}/day/$n';

  /// The day's hero card and one row per part. Ticks are dated [on] when a past date is picked; [moment] plays the
  /// card's part of moment A.
  List<Widget> _devotional(
    BuildContext context,
    WidgetRef ref,
    PublicStudy study,
    PublicStudy original,
    DevotionalDay day,
    StudyProgress progress, {
    String? on,
    required bool moment,
  }) {
    final l = AppLocalizations.of(context)!;
    final progressId = original.id;
    final ticked = progress.days[day.number]?.parts ?? const <DayPart>{};
    final done = progress.isDone(day);
    // The reader is told it came from Today, and which past date was shown, so its ticks and its way back match.
    void openDay() =>
        context.push(_dayPath(study, day.number), extra: ReaderEntry(study: original, fromToday: true, on: on));
    final parts = partsFor(day);
    return [
      Pressable(
        onPressed: openDay,
        haptic: true,
        borderRadius: BorderRadius.circular(Radii.card),
        child: DayHero(
          tag: dayHeroTag(progressId, day.number),
          child: HeroCard(
            eyebrow: '${study.title} · ${l.dayOfTotal(day.number, study.days.length)}',
            // Only the title: the card is the way into the day, and the reader's card adds the main idea.
            title: day.title,
            glow: done,
            animateGlow: moment,
            art: SelahArt(artKey: day.artKey, seed: '${study.id}-${day.number}', radius: 0, placeholder: false),
          ),
        ),
      ),
      const SizedBox(height: Space.l),
      for (var i = 0; i < parts.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.s + 2),
          child: Entrance(
            index: i,
            child: PartRow(
              part: parts[i],
              // Today keeps its full "Bible reading" label.
              title: parts[i] == DayPart.reading ? l.bibleReading : partLabel(l, parts[i]),
              subtitle: parts[i] == DayPart.reading ? day.bibleReading : null,
              ticked: ticked.contains(parts[i]),
              onTick: () => tickWithFeedback(ref, progressId, day, parts[i], ref.read(clockProvider)(), on: on),
              onOpen: parts[i] == DayPart.reading ? () => _openBible(day.bibleReading!, study.bibleVersionCode) : openDay,
            ),
          ),
        ),
    ];
  }
}

String _capitalised(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// Swaps Today's content when another date is picked: it slides 24px the way the selection moved (later dates come in
/// from the right) and fades, or only fades with Reduce Motion.
class _DaySwitch extends StatefulWidget {
  const _DaySwitch({required this.date, required this.child});

  /// The date shown (`yyyy-MM-dd`); the child's key must change with it.
  final String date;
  final Widget child;

  @override
  State<_DaySwitch> createState() => _DaySwitchState();
}

class _DaySwitchState extends State<_DaySwitch> {
  /// 1 when the last move went to a later date, -1 to an earlier one.
  double _direction = 1;

  @override
  void didUpdateWidget(_DaySwitch old) {
    super.didUpdateWidget(old);
    if (widget.date != old.date) _direction = widget.date.compareTo(old.date) > 0 ? 1 : -1;
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotion(context);
    return AnimatedSwitcher(
      duration: Motion.daySwitch,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == widget.child.key;
        // The outgoing copy leaves its heroes behind, so two cards never share a hero tag.
        Widget moved = incoming ? child : HeroMode(enabled: false, child: child);
        if (!reduce) {
          moved = AnimatedBuilder(
            animation: animation,
            child: moved,
            builder: (context, child) => Transform.translate(
              offset: Offset((incoming ? 1 : -1) * _direction * Motion.daySwitchShift * (1 - animation.value), 0),
              child: child,
            ),
          );
        }
        return FadeTransition(opacity: animation, child: moved);
      },
      child: widget.child,
    );
  }
}

/// The load error with a button to try again.
class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l.loadError, style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: Space.m),
      OutlinedButton(onPressed: onRetry, child: Text(l.retry)),
    ]);
  }
}

void _openBible(String reference, String versionCode) =>
    launchUrl(bibleReaderUrl(reference, versionCode), mode: LaunchMode.externalApplication);
