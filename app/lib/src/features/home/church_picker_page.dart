import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../data/current_church.dart';
import '../../data/providers.dart';
import '../church/role_label.dart';

/// Every church on Selah, the person's own first. Picking one makes it the app's church.
class ChurchPickerPage extends ConsumerWidget {
  const ChurchPickerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.pickChurch)),
        body: RefreshIndicator(
          onRefresh: () => refreshChurches(ref),
          child: const PageBody(children: [ChurchList()]),
        ),
      );
}

Future<void> refreshChurches(WidgetRef ref) async {
  ref.invalidate(myChurchesProvider);
  ref.invalidate(publicChurchesProvider);
  await ref.read(publicChurchesProvider.future);
}

/// The picker's list: the person's churches with their role, then every public church.
class ChurchList extends ConsumerWidget {
  const ChurchList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final churches = ref.watch(publicChurchesProvider);
    final mine = ref.watch(myChurchesProvider).value ?? const <Membership>[];
    final signedIn = ref.watch(userIdProvider).value != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      ],
    );
  }
}

class _ChurchTile extends ConsumerWidget {
  const _ChurchTile({required this.church, this.subtitle});

  final Church church;
  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            title: Text(church.name, style: Theme.of(context).textTheme.titleLarge),
            subtitle: subtitle == null ? null : Text(subtitle!),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ref.read(chosenChurchSlugProvider.notifier).choose(church.slug);
              context.go('/');
            },
          ),
        ),
      );
}
