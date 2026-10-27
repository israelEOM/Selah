import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../data/providers.dart';
import '../../l10n/locale.dart';
import '../home/language_menu.dart';
import 'church_switcher.dart';

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
    final role = roleState.value;
    final canEdit = role?.canEdit ?? false;
    final signedIn = ref.watch(userIdProvider).value != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(church.name, style: text.titleLarge),
        actions: [
          ChurchSwitcher(current: church, admin: false),
          const LanguageMenu(),
          if (canEdit)
            TextButton(onPressed: () => context.push('/c/${church.slug}/admin'), child: Text(l.manage))
          else if (signedIn && roleState.hasValue && role == null)
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
          if (signedIn)
            TextButton(onPressed: () => ref.read(repositoryProvider).signOut(), child: Text(l.signOut))
          else
            TextButton(
              onPressed: () => context.push('/login?next=${Uri.encodeQueryComponent('/c/${church.slug}')}'),
              child: Text(l.signIn),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(publishedStudiesProvider(church.id).future),
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
                    onPressed: () => ref.invalidate(publishedStudiesProvider(church.id)),
                    child: Text(l.retry),
                  ),
                ),
              ],
              data: (items) => items.isEmpty
                  ? [Text(l.noStudiesYet, style: text.bodyMedium)]
                  : [
                      Eyebrow(l.devotionalOfTheWeek),
                      const SizedBox(height: 12),
                      _StudyTile(church, items.first.localizedTo(language), featured: true),
                      if (items.length > 1) ...[
                        const SizedBox(height: 36),
                        Eyebrow(l.recentStudies),
                        const SizedBox(height: 12),
                        for (final study in items.skip(1))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _StudyTile(church, study.localizedTo(language)),
                          ),
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
  const _StudyTile(this.church, this.study, {this.featured = false});

  final Church church;
  final StudyCard study;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/c/${church.slug}/studies/${study.slug}'),
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
