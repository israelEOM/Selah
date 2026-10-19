import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../data/providers.dart';
import '../../l10n/locale.dart';
import 'language_menu.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final studies = ref.watch(publishedStudiesProvider);
    final language = ref.watch(appLocaleProvider).languageCode;
    final isAdmin = ref.watch(isAdminProvider).value ?? false;
    final signedIn = ref.watch(userIdProvider).value != null;
    return Scaffold(
      appBar: AppBar(
        title: Text('Selah.', style: text.headlineMedium),
        actions: [
          const LanguageMenu(),
          if (isAdmin)
            TextButton(onPressed: () => context.push('/admin'), child: Text(l.admin))
          else if (signedIn)
            TextButton(onPressed: () => ref.read(repositoryProvider).signOut(), child: Text(l.signOut))
          else
            TextButton(onPressed: () => context.push('/login'), child: Text(l.signIn)),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(publishedStudiesProvider.future),
        child: PageBody(
          children: [
            const SizedBox(height: 16),
            Eyebrow(l.heroEyebrow),
            const SizedBox(height: 12),
            Text('${l.tagline}.', style: text.displaySmall),
            const SizedBox(height: 12),
            Text(l.heroBody, style: text.bodyLarge),
            const SizedBox(height: 36),
            ...studies.when(
              loading: () => [
                const Center(
                  child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
                ),
              ],
              error: (_, _) => [
                Text(l.loadError, style: text.bodyMedium),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () => ref.invalidate(publishedStudiesProvider),
                    child: Text(l.retry),
                  ),
                ),
              ],
              data: (items) => items.isEmpty
                  ? [Text(l.noStudiesYet, style: text.bodyMedium)]
                  : [
                      Eyebrow(l.devotionalOfTheWeek),
                      const SizedBox(height: 12),
                      _StudyTile(items.first.localizedTo(language), featured: true),
                      if (items.length > 1) ...[
                        const SizedBox(height: 36),
                        Eyebrow(l.recentStudies),
                        const SizedBox(height: 12),
                        for (final study in items.skip(1))
                          Padding(padding: const EdgeInsets.only(bottom: 12), child: _StudyTile(study.localizedTo(language))),
                      ],
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StudyTile extends StatelessWidget {
  const _StudyTile(this.study, {this.featured = false});

  final StudyCard study;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/studies/${study.slug}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (study.thumbnailUrl != null)
              AspectRatio(
                aspectRatio: featured ? 16 / 9 : 21 / 9,
                child: Image.network(
                  study.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(color: SelahColors.sage),
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
    );
  }
}
