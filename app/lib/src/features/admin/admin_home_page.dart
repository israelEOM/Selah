import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/design/art.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../data/providers.dart';
import 'admin_gate.dart';
import 'admin_motion.dart';

class AdminHomePage extends ConsumerWidget {
  const AdminHomePage({super.key, required this.church});

  final Church church;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final sermons = ref.watch(sermonsProvider(church.id));
    final isOwner = ref.watch(churchRoleProvider(church.id)).value == ChurchRole.owner;
    final base = '/c/${church.slug}/admin';
    final used = ref.watch(sermonsThisMonthProvider(church.id)).value;
    final limit = church.monthlySermonLimit;
    final atLimit = used != null && limit != null && used >= limit;
    return AdminPage(church: church, backTo: '/c/${church.slug}', children: [
      Eyebrow(l.admin),
      const SizedBox(height: 8),
      Text(l.adminTitle, style: text.headlineMedium),
      if (used != null && limit != null) ...[
        const SizedBox(height: 6),
        Text(l.sermonsThisMonth(used, limit), style: text.bodyMedium),
        const SizedBox(height: 8),
        _UsageBar(fraction: limit == 0 ? 1 : (used / limit).clamp(0.0, 1.0)),
      ],
      const SizedBox(height: 20),
      Wrap(spacing: 12, runSpacing: 8, children: [
        FilledButton(
          onPressed: atLimit ? null : () => context.go('$base/sermons/new'),
          child: Text(l.importSermon),
        ),
        if (isOwner) OutlinedButton(onPressed: () => context.go('$base/people'), child: Text(l.people)),
        if (isOwner) OutlinedButton(onPressed: () => context.go('$base/settings'), child: Text(l.churchSettings)),
      ]),
      if (atLimit) ...[
        const SizedBox(height: 10),
        Text(l.monthlyLimitReached(limit), style: text.bodyMedium),
      ],
      const SizedBox(height: 24),
      ...sermons.when(
        loading: () => [const Center(child: CircularProgressIndicator())],
        error: (_, _) => [Text(l.loadError, style: text.bodyMedium)],
        data: (items) => items.isEmpty
            ? [Text(l.adminEmpty, style: text.bodyMedium)]
            : [
                for (final sermon in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        leading: SelahArt(artKey: sermon.artKey, seed: sermon.studyId ?? sermon.id, width: 46, height: 46, radius: 10),
                        title: Text(sermon.title, style: text.titleLarge),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Align(alignment: Alignment.centerLeft, child: _StatusChip(status: sermon.studyStatus)),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go('$base/sermons/${sermon.id}'),
                      ),
                    ),
                  ),
              ],
      ),
    ]);
  }
}

/// The month's usage, filling from empty in terracotta.
class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: fraction),
          duration: reduceMotion(context) ? Duration.zero : Motion.long,
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => LinearProgressIndicator(
            key: const ValueKey('usage-bar'),
            value: value,
            minHeight: 6,
            color: context.tones.accent,
            backgroundColor: context.tones.surface,
          ),
        ),
      );
}

/// A study's status: green when published, terracotta in review, and a slow shimmer while generating.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final tones = context.tones;
    final colour = switch (status) {
      'published' => tones.done,
      'review' => tones.accent,
      _ => tones.muted,
    };
    Widget chip = Text(
      studyStatusLabel(l, status).toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colour),
    );
    if (status == 'generating') chip = Shimmer(key: const ValueKey('shimmer'), child: chip);
    return chip;
  }
}
