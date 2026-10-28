import 'package:flutter/cupertino.dart' show CupertinoIcons;
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
import 'study_widgets.dart';
import 'translation_banner.dart';

class StudyPage extends ConsumerWidget {
  const StudyPage({super.key, required this.church, required this.slug});

  final Church church;
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final study = ref.watch(studyProvider((churchId: church.id, slug: slug)));
    final backTo = '/c/${church.slug}';
    SelahPage page(List<Widget> children) => SelahPage(
          backTo: backTo,
          actions: const [LanguageMenu(), SizedBox(width: 8)],
          children: children,
        );
    return study.when(
      loading: () => page(const [SkeletonList(hero: true, rows: 4)]),
      error: (_, _) => page([Text(l.loadError, style: text.bodyLarge)]),
      data: (s) => s == null
          ? page([Text(l.studyNotFound, style: text.bodyLarge)])
          : _StudyBody(church: church, original: s),
    );
  }
}

class _StudyBody extends ConsumerWidget {
  const _StudyBody({required this.church, required this.original});

  final Church church;
  final PublicStudy original;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final language = ref.watch(appLocaleProvider).languageCode;
    final study = studyToShow(original, language, showOriginal: ref.watch(showOriginalProvider(original.id)));
    final progress = ref.watch(studyProgressProvider(original.id)).value;
    final summary = study.summary;
    final points = List<Map<String, dynamic>>.from(summary['points'] as List? ?? const []);
    final takeaways = List<String>.from(summary['key_takeaways'] as List? ?? const []);
    final byline = [study.sermon.preacher ?? study.sermon.channel, l.daysCount(study.numberOfDays)].whereType<String>();
    return SelahPage(
      backTo: '/c/${church.slug}',
      actions: const [LanguageMenu(), SizedBox(width: 8)],
      children: [
        TranslationBanner(shown: study, original: original, language: language),
        if (study.sermon.thumbnailUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                study.sermon.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(color: context.tones.surface),
              ),
            ),
          ),
        const SizedBox(height: 20),
        Text(study.title, style: text.headlineMedium),
        const SizedBox(height: 8),
        Text(byline.join(' · '), style: text.bodyMedium),
        ExternalLink(label: l.watchSermon, uri: youtubeAt(study.sermon.videoId, null)),
        if (study.centralMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(left: 16),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
            ),
            child: Text(study.centralMessage!, style: text.bodyLarge),
          ),
        ],
        ReadingSection(
          label: l.devotionalPath,
          child: Column(
            children: [
              for (final (i, day) in study.days.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Entrance(
                    index: i,
                    child: SelahRow(
                      label: day.title,
                      detail: day.bibleReading,
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (progress?.isDone(day) ?? false)
                          Icon(Icons.check_circle, color: context.tones.done)
                        else
                          Text('${day.number}', style: text.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
                        const SizedBox(width: Space.s),
                        Icon(
                          uiPlatformOf(context) == UiPlatform.ios ? CupertinoIcons.chevron_forward : Icons.chevron_right,
                          color: context.tones.muted,
                          size: uiPlatformOf(context) == UiPlatform.ios ? 18 : 24,
                        ),
                      ]),
                      onOpen: () => context.push('/c/${church.slug}/studies/${study.slug}/day/${day.number}', extra: original),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (points.isNotEmpty || summary['introduction'] != null)
          ReadingSection(
            label: l.sermonSummary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (summary['main_passage'] != null)
                  ExternalLink(
                    icon: Icons.menu_book_outlined,
                    label: l.readReference(summary['main_passage'] as String, study.bibleVersionCode),
                    uri: bibleReaderUrl(summary['main_passage'] as String, study.bibleVersionCode),
                  ),
                if (summary['introduction'] != null) Text(summary['introduction'] as String, style: text.bodyLarge),
                for (final point in points) ...[
                  const SizedBox(height: 24),
                  Text(point['title'] as String, style: text.titleLarge),
                  const SizedBox(height: 6),
                  Text(point['summary'] as String, style: text.bodyLarge),
                  if ((point['references'] as List?)?.isNotEmpty ?? false)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text((point['references'] as List).join(' · '), style: text.labelSmall),
                    ),
                  if (point['start_seconds'] != null)
                    ExternalLink(
                      label: l.watchMoment(clock(point['start_seconds'] as num)),
                      uri: youtubeAt(study.sermon.videoId, point['start_seconds'] as num),
                    ),
                ],
                if (summary['conclusion'] != null) ...[
                  const SizedBox(height: 24),
                  Text(summary['conclusion'] as String, style: text.bodyLarge),
                ],
              ],
            ),
          ),
        if (takeaways.isNotEmpty)
          ReadingSection(
            label: l.keyTakeaways,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final t in takeaways)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('• $t', style: text.bodyLarge),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 32),
        Text(l.aiNotice, style: text.bodyMedium?.copyWith(fontSize: 13)),
      ],
    );
  }
}
