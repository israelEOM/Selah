import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/design/art.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../data/progress.dart';
import '../../data/providers.dart';
import '../../l10n/locale.dart';

/// A church's front page: its published studies, newest first.
class ChurchPage extends ConsumerWidget {
  const ChurchPage({super.key, required this.church});

  final Church church;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final studies = ref.watch(publishedStudiesProvider(church.id));
    final language = ref.watch(appLocaleProvider).languageCode;
    final roleState = ref.watch(churchRoleProvider(church.id));
    final signedIn = ref.watch(userIdProvider).value != null;
    final site = siteLayout(context);
    return SelahPage(
      title: church.name,
      onRefresh: () => ref.refresh(publishedStudiesProvider(church.id).future),
      lazy: true,
      wide: site,
      actions: [
        if (signedIn && roleState.hasValue && roleState.value == null)
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref.read(repositoryProvider).joinChurch(church.id);
                ref.invalidate(churchRoleProvider(church.id));
                ref.invalidate(myChurchesProvider);
              } catch (_) {
                messenger.showSnackBar(SnackBar(content: Text(l.genericError)));
              }
            },
            child: Text(l.followChurch),
          ),
        const SizedBox(width: 8),
      ],
      children: [
        // On a wide page the intro keeps a reading width.
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: site ? Layout.readingMeasure : double.infinity),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(l.heroEyebrow),
                const SizedBox(height: Space.m),
                Text('${l.tagline}.', style: text.displaySmall),
                const SizedBox(height: Space.m),
                Text(l.heroBody, style: text.bodyLarge),
              ],
            ),
          ),
        ),
        const SizedBox(height: 36),
        ...studies.when(
          loading: () => [const SkeletonList(rows: 4)],
          error: (_, _) => [
            Text(l.loadError, style: text.bodyMedium),
            const SizedBox(height: Space.m),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () => ref.invalidate(publishedStudiesProvider(church.id)),
                child: Text(l.retry),
              ),
            ),
          ],
          data: (items) => items.isEmpty
              ? [
                  const SelahArt(
                    artKey: 'scene-empty-studies',
                    fixed: true,
                    seed: 'empty-studies',
                    width: double.infinity,
                    height: 180,
                  ),
                  const SizedBox(height: Space.l),
                  Text(l.noStudiesYet, style: text.bodyMedium),
                ]
              : [
                  if (site) ...[
                    Eyebrow(l.devotionalOfTheWeek),
                    const SizedBox(height: Space.m),
                    Entrance(
                      index: 0,
                      child: _StudyTile(church, items.first.localizedTo(language), featured: true, horizontal: true),
                    ),
                  ] else
                    Entrance(index: 0, child: _FeaturedStudy(church, items.first.localizedTo(language))),
                  if (items.length > 1) ...[
                    const SizedBox(height: 36),
                    Eyebrow(l.recentStudies),
                    const SizedBox(height: Space.m),
                    if (site)
                      CardGrid(
                        minTileWidth: 300,
                        children: [
                          for (final (i, study) in items.skip(1).indexed)
                            Entrance(index: i + 1, child: _StudyTile(church, study.localizedTo(language))),
                        ],
                      )
                    else
                      for (final (i, study) in items.skip(1).indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.m),
                          child: Entrance(index: i + 1, child: _StudyRow(church, study.localizedTo(language))),
                        ),
                  ],
                ],
        ),
      ],
    );
  }
}

/// How far through a study someone is, from their saved progress. A day counts as done once it has a finish date,
/// or all three parts (old `read:` marks have no date).
({int done, int current}) studyStanding(StudyProgress? progress, int numberOfDays) {
  bool isDone(int n) {
    final day = progress?.days[n];
    return day != null && (day.doneOn != null || day.parts.containsAll(DayPart.values));
  }

  final done = [for (var n = 1; n <= numberOfDays; n++) if (isDone(n)) n];
  final current = [for (var n = 1; n <= numberOfDays; n++) n].where((n) => !isDone(n)).firstOrNull ?? numberOfDays;
  return (done: done.length, current: current);
}

/// The newest study in the app layout: its art, the day someone is on, a progress line and Continue.
class _FeaturedStudy extends ConsumerWidget {
  const _FeaturedStudy(this.church, this.study);

  final Church church;
  final StudyCard study;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(Radii.card);
    final n = study.numberOfDays;
    final standing = studyStanding(ref.watch(studyProgressProvider(study.id)).value, n);
    final fraction = n == 0 ? 0.0 : standing.done / n;
    void open() => context.push('/c/${church.slug}/studies/${study.slug}');
    return Pressable(
      onPressed: open,
      borderRadius: radius,
      haptic: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: context.tones.surface, borderRadius: radius),
        child: Padding(
          padding: const EdgeInsets.all(Space.s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelahArt(
                artKey: study.artKey,
                seed: study.id,
                width: double.infinity,
                height: 130,
                heroTag: studyArtTag(study.id),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, Space.l, 10, Space.s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(l.devotionalOfTheWeek),
                    const SizedBox(height: 6),
                    Text(study.title, style: text.headlineSmall),
                    const SizedBox(height: 6),
                    Text('${l.daysCount(n)} · ${l.dayOfTotal(standing.current, n)}', style: text.bodyMedium),
                    const SizedBox(height: Space.m),
                    _FillingLine(value: fraction),
                    const SizedBox(height: Space.l),
                    FilledButton(onPressed: open, child: Text(l.continueStudy)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A progress line that fills from empty when it first appears, then follows [value]. Shown at once with Reduce
/// Motion.
class _FillingLine extends StatelessWidget {
  const _FillingLine({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduceMotion(context) ? value : 0, end: value),
      duration: reduceMotion(context) ? Duration.zero : Motion.long,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => LinearProgressIndicator(
        value: v,
        minHeight: 4,
        borderRadius: BorderRadius.circular(Radii.chip),
        backgroundColor: Color.lerp(context.tones.surface, Colors.black, 0.08),
      ),
    );
  }
}

/// A recent study in the app layout: a square of its art, the title and the length.
class _StudyRow extends StatelessWidget {
  const _StudyRow(this.church, this.study);

  final Church church;
  final StudyCard study;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SelahRow(
      leading: SelahArt(
        artKey: study.artKey,
        seed: study.id,
        width: 52,
        height: 52,
        radius: Radii.control,
        heroTag: studyArtTag(study.id),
      ),
      label: study.title,
      detail: [if (study.preacher != null) study.preacher!, l.daysCount(study.numberOfDays)].join(' · '),
      onOpen: () => context.push('/c/${church.slug}/studies/${study.slug}'),
    );
  }
}

class _StudyTile extends StatelessWidget {
  const _StudyTile(this.church, this.study, {this.featured = false, this.horizontal = false});

  final Church church;
  final StudyCard study;
  final bool featured;

  /// The thumbnail on the left half and the text on the right, for the featured study on a wide page.
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(Radii.card);
    final thumbnail = study.thumbnailUrl == null
        ? null
        : AspectRatio(
            aspectRatio: featured ? 16 / 9 : 21 / 9,
            child: Image.network(
              study.thumbnailUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ColoredBox(color: context.tones.surface),
            ),
          );
    final details = Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(study.title, style: featured ? text.headlineSmall : text.titleLarge),
          const SizedBox(height: 6),
          Text(
            [if (study.preacher != null) study.preacher!, l.daysCount(study.numberOfDays)].join(' · '),
            style: text.bodyMedium,
          ),
          if (featured && study.centralMessage != null) ...[
            const SizedBox(height: 10),
            Text(study.centralMessage!, style: text.bodyMedium, maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
    return Pressable(
      onPressed: () => context.push('/c/${church.slug}/studies/${study.slug}'),
      borderRadius: radius,
      haptic: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: context.tones.surface, borderRadius: radius),
        child: ClipRRect(
          borderRadius: radius,
          child: horizontal
              ? Row(children: [if (thumbnail != null) Expanded(child: thumbnail), Expanded(child: details)])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [?thumbnail, details]),
        ),
      ),
    );
  }
}
