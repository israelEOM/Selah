import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../data/current_church.dart';
import '../../data/progress.dart';
import '../../data/providers.dart';
import '../../l10n/locale.dart';
import '../home/church_picker_page.dart';
import '../study/translation_banner.dart';
import 'part_tick.dart';
import 'today_refresh.dart';
import 'today_state.dart';

/// Ticks [part] and, when that finishes the day, plays the success haptic. Hoy and the reader both tick through this.
Future<void> tickWithFeedback(WidgetRef ref, String progressId, DevotionalDay day, DayPart part, DateTime now) async {
  await tickPart(ref, progressId, day, part, now);
  // A toggle can only finish the day by adding its last part, so done now means it just became done.
  if ((await loadProgress(progressId)).isDone(day)) await SelahHaptics.success();
}

/// The Hoy tab: today's part of the church's newest study, or the church list when none is chosen yet.
class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return ref.watch(currentChurchProvider).when(
          loading: () => SelahPage(title: l.tabToday, children: const [SkeletonList(hero: true, rows: 3)]),
          error: (_, _) => SelahPage(
            title: l.tabToday,
            children: [_LoadError(onRetry: () => ref.invalidate(currentChurchProvider))],
          ),
          data: (church) => church == null
              ? SelahPage(title: l.pickChurch, onRefresh: () => refreshChurches(ref), children: const [ChurchList()])
              : TodayRefresher(churchId: church.id, child: _Today(church: church)),
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
    final eyebrowStyle = text.labelMedium?.copyWith(color: context.tones.muted, fontWeight: FontWeight.w600, letterSpacing: 1);
    final header = [
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(DateFormat.MMMMEEEEd(l.localeName).format(now).toUpperCase(), style: eyebrowStyle),
          Text('  ·  ', style: eyebrowStyle),
          Text(church.name, style: eyebrowStyle),
        ],
      ),
      const SizedBox(height: Space.l),
      _WeekRow(doneDates: ref.watch(doneDatesProvider).value ?? const {}, now: now),
      const SizedBox(height: Space.xl),
    ];
    Widget page(List<Widget> children) => SelahPage(
          title: l.tabToday,
          onRefresh: () => refreshToday(ref, church.id),
          children: [...header, ...children],
        );
    final loading = page(const [SkeletonList(hero: true, rows: 3)]);
    return ref.watch(newestStudyProvider(church.id)).when(
          loading: () => loading,
          error: (_, _) => page([_LoadError(onRetry: () => ref.invalidate(newestStudyProvider(church.id)))]),
          data: (original) {
            if (original == null) {
              return page([
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
                    return page(switch (state) {
                      NoStudy() => const [],
                      DayToDo(:final day) => [
                          ..._devotional(context, ref, study, original.id, day, progress, done: false),
                          summary,
                        ],
                      DoneForToday(:final day, :final next) => [
                          ..._devotional(context, ref, study, original.id, day, progress, done: true),
                          if (next != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () => context.push(_dayPath(study, next.number)),
                                child: Text(l.readNext),
                              ),
                            ),
                          summary,
                        ],
                      AllDone(:final passage, :final takeaway) => [
                          Text(l.meditateToday, style: text.headlineMedium),
                          if (passage != null || takeaway != null) ...[
                            const SizedBox(height: Space.l),
                            HeroCard(eyebrow: passage == null ? null : '${l.todayMainPassage} · $passage', quote: takeaway),
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
                    });
                  },
                );
          },
        );
  }

  String _dayPath(PublicStudy study, int n) => '/c/${church.slug}/studies/${study.slug}/day/$n';

  List<Widget> _devotional(
    BuildContext context,
    WidgetRef ref,
    PublicStudy study,
    String progressId,
    DevotionalDay day,
    StudyProgress progress, {
    required bool done,
  }) {
    final l = AppLocalizations.of(context)!;
    final ticked = progress.days[day.number]?.parts ?? const <DayPart>{};
    void openDay() => context.push(_dayPath(study, day.number));
    String label(DayPart part) => switch (part) {
          DayPart.reading => l.bibleReading,
          DayPart.reflection => l.reflection,
          DayPart.prayer => l.prayer,
        };
    final parts = partsFor(day);
    return [
      Pressable(
        onPressed: openDay,
        haptic: true,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Hero(
          tag: dayHeroTag(progressId, day.number),
          child: HeroCard(
            eyebrow: '${study.title} · ${l.dayOfTotal(day.number, study.days.length)}',
            title: day.title,
            quote: day.mainIdea,
            badge: done ? l.doneForToday : null,
          ),
        ),
      ),
      const SizedBox(height: Space.l),
      for (var i = 0; i < parts.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.s + 2),
          child: Entrance(
            index: i,
            child: SelahRow(
              label: label(parts[i]),
              detail: parts[i] == DayPart.reading ? day.bibleReading : null,
              trailing: PartTick(
                key: ValueKey('tick-${parts[i].name}'),
                label: label(parts[i]),
                ticked: ticked.contains(parts[i]),
                onTap: () => tickWithFeedback(ref, progressId, day, parts[i], ref.read(clockProvider)()),
              ),
              onOpen: parts[i] == DayPart.reading ? () => _openBible(day.bibleReading!, study.bibleVersionCode) : openDay,
            ),
          ),
        ),
    ];
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

/// Monday to Sunday, today ringed and finished days filled with a check that springs in.
class _WeekRow extends StatelessWidget {
  const _WeekRow({required this.doneDates, required this.now});

  final Set<String> doneDates;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!.localeName;
    final tones = context.tones;
    final done = weekCircles(doneDates, now);
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    return Row(
      key: const ValueKey('week'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 7; i++)
          Column(
            key: ValueKey('week-$i'),
            children: [
              Text(
                DateFormat.E(locale).format(DateTime(monday.year, monday.month, monday.day + i)).substring(0, 1).toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: tones.muted),
              ),
              const SizedBox(height: 6),
              SpringIn(
                active: done[i],
                child: AnimatedContainer(
                  duration: reduceMotion(context) ? Duration.zero : Motion.medium,
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done[i] ? tones.done : tones.surface,
                    border: i == now.weekday - 1 ? Border.all(color: tones.today, width: 2) : null,
                  ),
                  child: done[i] ? Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.onPrimary) : null,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
