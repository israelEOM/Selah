import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
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
    return SelahPage(
      title: church.name,
      onRefresh: () => ref.refresh(publishedStudiesProvider(church.id).future),
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
        Eyebrow(l.heroEyebrow),
        const SizedBox(height: Space.m),
        Text('${l.tagline}.', style: text.displaySmall),
        const SizedBox(height: Space.m),
        Text(l.heroBody, style: text.bodyLarge),
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
              ? [Text(l.noStudiesYet, style: text.bodyMedium)]
              : [
                  Eyebrow(l.devotionalOfTheWeek),
                  const SizedBox(height: Space.m),
                  Entrance(index: 0, child: _StudyTile(church, items.first.localizedTo(language), featured: true)),
                  if (items.length > 1) ...[
                    const SizedBox(height: 36),
                    Eyebrow(l.recentStudies),
                    const SizedBox(height: Space.m),
                    for (final (i, study) in items.skip(1).indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.m),
                        child: Entrance(index: i + 1, child: _StudyTile(church, study.localizedTo(language))),
                      ),
                  ],
                ],
        ),
      ],
    );
  }
}

class _StudyTile extends StatelessWidget {
  const _StudyTile(this.church, this.study, {this.featured = false});

  final Church church;
  final StudyCard study;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(Radii.card);
    return Pressable(
      onPressed: () => context.push('/c/${church.slug}/studies/${study.slug}'),
      borderRadius: radius,
      haptic: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: context.tones.surface, borderRadius: radius),
        child: ClipRRect(
          borderRadius: radius,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (study.thumbnailUrl != null)
                AspectRatio(
                  aspectRatio: featured ? 16 / 9 : 21 / 9,
                  child: Image.network(
                    study.thumbnailUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(color: context.tones.surface),
                  ),
                ),
              Padding(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
