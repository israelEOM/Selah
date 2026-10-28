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
  Widget build(BuildContext context, WidgetRef ref) => SelahPage(
        title: AppLocalizations.of(context)!.pickChurch,
        onRefresh: () => refreshChurches(ref),
        children: const [ChurchList()],
      );
}

Future<void> refreshChurches(WidgetRef ref) async {
  ref.invalidate(myChurchesProvider);
  ref.invalidate(publicChurchesProvider);
  await ref.read(publicChurchesProvider.future);
}

/// The picker's list: the person's churches with their role, then every public church.
/// Picking one makes it the app's church and opens Today, unless [onPick] says otherwise.
/// A member who picks a church they don't belong to gets its page instead, where they can follow it:
/// the app only shows a member's own churches.
class ChurchList extends ConsumerWidget {
  const ChurchList({super.key, this.onPick});

  final void Function(Church church)? onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final churches = ref.watch(publicChurchesProvider);
    final mine = ref.watch(myChurchesProvider).value ?? const <Membership>[];
    final signedIn = ref.watch(userIdProvider).value != null;
    final mineOnly = signedIn && mine.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mineOnly) ...[
          Eyebrow(l.yourChurches),
          const SizedBox(height: 12),
          for (final (i, m) in mine.indexed)
            _ChurchTile(index: i, church: m.church, subtitle: roleLabel(l, m.role), onPick: onPick),
          const SizedBox(height: 24),
        ],
        Eyebrow(l.allChurches),
        const SizedBox(height: 12),
        ...churches.when(
          loading: () => [const SkeletonList(rows: 4)],
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
              : [
                  for (final (i, church) in items.indexed)
                    _ChurchTile(
                      index: mine.length + i,
                      church: church,
                      onPick: onPick,
                      opensPage: mineOnly && !mine.any((m) => m.church.id == church.id),
                    ),
                ],
        ),
      ],
    );
  }
}

class _ChurchTile extends ConsumerWidget {
  const _ChurchTile({required this.index, required this.church, this.subtitle, this.onPick, this.opensPage = false});

  /// Position in the page, for the staggered entrance.
  final int index;
  final Church church;
  final String? subtitle;
  final void Function(Church church)? onPick;

  /// Open the church's page rather than choosing it.
  final bool opensPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.only(bottom: Space.m),
        child: Entrance(
          index: index,
          child: SelahRow(
            label: church.name,
            detail: subtitle,
            onOpen: onPick != null
                ? () => onPick!(church)
                : opensPage
                    ? () => context.go('/c/${church.slug}')
                    : () {
                        ref.read(chosenChurchSlugProvider.notifier).choose(church.slug);
                        context.go('/');
                      },
          ),
        ),
      );
}
