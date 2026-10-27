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
import 'today_state.dart';

/// The Hoy tab: today's part of the church's newest study, or the church list when none is chosen yet.
class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    return ref.watch(currentChurchProvider).when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => Scaffold(body: PageBody(children: [Text(l.loadError, style: text.bodyLarge)])),
          data: (church) => church == null
              ? Scaffold(
                  appBar: AppBar(title: Text(l.pickChurch)),
                  body: RefreshIndicator(
                    onRefresh: () => refreshChurches(ref),
                    child: const PageBody(children: [ChurchList()]),
                  ),
                )
              : Scaffold(body: _Today(church: church)),
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
    final now = ref.watch(clockProvider)();
    final language = ref.watch(appLocaleProvider).languageCode;
    final header = [
      Text(church.name, style: text.titleMedium?.copyWith(color: context.tones.muted, fontWeight: FontWeight.w600)),
      const SizedBox(height: 16),
      _WeekRow(doneDates: ref.watch(doneDatesProvider).value ?? const {}, now: now),
      const SizedBox(height: 16),
      Text(
        DateFormat.MMMMEEEEd(l.localeName).format(now).toUpperCase(),
        style: text.labelMedium?.copyWith(color: context.tones.muted, letterSpacing: 1),
      ),
      const SizedBox(height: 6),
    ];
    Widget page(List<Widget> children) => PageBody(children: [...header, ...children]);
    const loading = Center(child: CircularProgressIndicator());
    final error = PageBody(children: [Text(l.loadError, style: text.bodyLarge)]);
    return ref.watch(newestStudyProvider(church.id)).when(
          loading: () => loading,
          error: (_, _) => error,
          data: (original) {
            if (original == null) {
              return page([
                const SizedBox(height: 20),
                Text(l.noStudiesYetToday, style: text.bodyLarge),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(onPressed: () => context.go('/c/${church.slug}'), child: Text(l.goToStudies)),
                ),
              ]);
            }
            return ref.watch(studyProgressProvider(original.id)).when(
                  loading: () => loading,
                  error: (_, _) => error,
                  data: (progress) {
                    final study = studyToShow(original, language, showOriginal: ref.watch(showOriginalProvider(original.id)));
                    final state = todayFor(study: study, progress: progress, now: now);
                    final summary = Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed: () => context.go('/c/${church.slug}/studies/${study.slug}'),
                          child: Text(l.sermonSummaryButton),
                        ),
                      ),
                    );
                    return page(switch (state) {
                      NoStudy() => const [],
                      DayToDo(:final day) => [
                          ..._devotional(context, ref, study, original.id, day, progress, now, done: false),
                          summary,
                        ],
                      DoneForToday(:final day, :final next) => [
                          ..._devotional(context, ref, study, original.id, day, progress, now, done: true),
                          if (next != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () => context.go(_dayPath(study, next.number)),
                                child: Text(l.readNext),
                              ),
                            ),
                          summary,
                        ],
                      AllDone(:final passage, :final takeaway) => [
                          const SizedBox(height: 6),
                          Text(l.meditateToday, style: text.headlineMedium),
                          if (passage != null || takeaway != null) ...[
                            const SizedBox(height: 20),
                            _HeroCard(eyebrow: passage == null ? null : '${l.todayMainPassage} · $passage', quote: takeaway),
                          ],
                          if (passage != null) ...[
                            const SizedBox(height: 16),
                            _Row(
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
    StudyProgress progress,
    DateTime now, {
    required bool done,
  }) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final ticked = progress.days[day.number]?.parts ?? const <DayPart>{};
    String label(DayPart part) => switch (part) {
          DayPart.reading => l.bibleReading,
          DayPart.reflection => l.reflection,
          DayPart.prayer => l.prayer,
        };
    return [
      Text(study.title, style: text.headlineMedium),
      const SizedBox(height: 10),
      Eyebrow('${l.todayDevotional} · ${l.dayOfTotal(day.number, study.days.length)}'),
      const SizedBox(height: 16),
      _HeroCard(eyebrow: day.title, quote: day.mainIdea, badge: done ? l.doneForToday : null),
      const SizedBox(height: 16),
      for (final part in partsFor(day))
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _Row(
            label: label(part),
            detail: part == DayPart.reading ? day.bibleReading : null,
            tickKey: ValueKey('tick-${part.name}'),
            ticked: ticked.contains(part),
            onTick: () => tickPart(ref, progressId, day, part, ref.read(clockProvider)()),
            onOpen: part == DayPart.reading
                ? () => _openBible(day.bibleReading!, study.bibleVersionCode)
                : () => context.go(_dayPath(study, day.number)),
          ),
        ),
    ];
  }
}

void _openBible(String reference, String versionCode) =>
    launchUrl(bibleReaderUrl(reference, versionCode), mode: LaunchMode.externalApplication);

/// Monday to Sunday, today ringed and finished days filled with a check.
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done[i] ? tones.done : tones.surface,
                  border: i == now.weekday - 1 ? Border.all(color: tones.today, width: 2) : null,
                ),
                child: done[i] ? Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.onPrimary) : null,
              ),
            ],
          ),
      ],
    );
  }
}

/// The gradient card with the day's main idea in a serif quote.
class _HeroCard extends StatelessWidget {
  const _HeroCard({this.eyebrow, this.quote, this.badge});

  final String? eyebrow;
  final String? quote;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final tones = context.tones;
    final scheme = Theme.of(context).colorScheme;
    // The hero is dark in both themes: white on the light theme's green, the dark theme's light text on brown.
    final onHero = Theme.of(context).brightness == Brightness.light ? scheme.onPrimary : scheme.onSurface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tones.heroStart, tones.heroEnd],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: ShapeDecoration(shape: const StadiumBorder(), color: onHero.withValues(alpha: 0.16)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check, size: 14, color: onHero),
                const SizedBox(width: 4),
                Text(badge!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: onHero)),
              ]),
            ),
            const SizedBox(height: 14),
          ],
          if (eyebrow != null)
            Text(
              eyebrow!.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: onHero.withValues(alpha: 0.8)),
            ),
          if (eyebrow != null && quote != null) const SizedBox(height: 12),
          if (quote != null) Text(quote!, style: serifQuote(context).copyWith(color: onHero)),
        ],
      ),
    );
  }
}

/// A row that opens its part, with an optional round tick on the right.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.onOpen, this.detail, this.tickKey, this.ticked, this.onTick});

  final String label;
  final String? detail;
  final VoidCallback onOpen;
  final Key? tickKey;

  /// Null for a row without a tick.
  final bool? ticked;
  final VoidCallback? onTick;

  @override
  Widget build(BuildContext context) {
    final tones = context.tones;
    final text = Theme.of(context).textTheme;
    return Material(
      color: tones.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (detail != null) Text(detail!, style: text.bodyMedium?.copyWith(color: tones.muted)),
              ]),
            ),
            if (ticked == null)
              Icon(Icons.chevron_right, color: tones.muted)
            else
              Semantics(
                button: true,
                checked: ticked,
                label: label,
                child: InkResponse(
                  key: tickKey,
                  onTap: onTick,
                  radius: 24,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ticked! ? tones.done : null,
                      border: ticked! ? null : Border.all(color: tones.muted, width: 1.5),
                    ),
                    child: ticked! ? Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.onPrimary) : null,
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
