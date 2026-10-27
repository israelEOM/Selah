import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../data/providers.dart';
import 'language_menu.dart';

/// The front door: the person's churches, then every church on Selah.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final churches = ref.watch(publicChurchesProvider);
    final mine = ref.watch(myChurchesProvider).value ?? const <Membership>[];
    final signedIn = ref.watch(userIdProvider).value != null;
    return Scaffold(
      appBar: AppBar(
        title: Text('Selah.', style: text.headlineMedium),
        actions: [
          const LanguageMenu(),
          if (signedIn)
            TextButton(onPressed: () => ref.read(repositoryProvider).signOut(), child: Text(l.signOut))
          else
            TextButton(onPressed: () => context.push('/login'), child: Text(l.signIn)),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myChurchesProvider);
          ref.invalidate(publicChurchesProvider);
          await ref.read(publicChurchesProvider.future);
        },
        child: PageBody(
          children: [
            const SizedBox(height: 16),
            Eyebrow(l.heroEyebrow),
            const SizedBox(height: 12),
            Text('${l.tagline}.', style: text.displaySmall),
            const SizedBox(height: 36),
            if (signedIn && mine.isNotEmpty) ...[
              Eyebrow(l.yourChurches),
              const SizedBox(height: 12),
              for (final m in mine) _ChurchTile(church: m.church, subtitle: roleLabel(l, m.role)),
              const SizedBox(height: 24),
            ],
            Eyebrow(l.allChurches),
            const SizedBox(height: 12),
            ...churches.when(
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
                    onPressed: () => ref.invalidate(publicChurchesProvider),
                    child: Text(l.retry),
                  ),
                ),
              ],
              data: (items) => items.isEmpty
                  ? [Text(l.noStudiesYet, style: text.bodyMedium)]
                  : [for (final church in items) _ChurchTile(church: church)],
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l.createChurch),
                onPressed: () => context.push(signedIn ? '/churches/new' : '/login?next=/churches/new'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String roleLabel(AppLocalizations l, ChurchRole role) => switch (role) {
      ChurchRole.owner => l.roleOwner,
      ChurchRole.editor => l.roleEditor,
      ChurchRole.member => l.roleMember,
    };

class _ChurchTile extends StatelessWidget {
  const _ChurchTile({required this.church, this.subtitle});

  final Church church;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            title: Text(church.name, style: Theme.of(context).textTheme.titleLarge),
            subtitle: subtitle == null ? null : Text(subtitle!),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/c/${church.slug}'),
          ),
        ),
      );
}
