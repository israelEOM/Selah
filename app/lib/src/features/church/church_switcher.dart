import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/models.dart';
import '../../data/providers.dart';

/// App-bar menu for moving between the churches a person belongs to. Labelled with the current
/// church's name; hidden unless the person belongs to more than one church.
class ChurchSwitcher extends ConsumerWidget {
  const ChurchSwitcher({super.key, required this.current, required this.admin});

  final Church current;

  /// Whether the screen being left is an admin one, so that picking a church the person can edit
  /// keeps them in admin.
  final bool admin;

  static const _create = '\u0000create';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberships = ref.watch(myChurchesProvider).value ?? const <Membership>[];
    if (memberships.length < 2) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == _create) {
          context.push('/churches/new');
          return;
        }
        final picked = memberships.firstWhere((m) => m.church.slug == value);
        final base = '/c/${picked.church.slug}';
        context.go(admin && picked.role.canEdit ? '$base/admin' : base);
      },
      itemBuilder: (_) => [
        for (final m in memberships) PopupMenuItem(value: m.church.slug, child: Text(m.church.name)),
        const PopupMenuDivider(),
        PopupMenuItem(value: _create, child: Text(l.createChurch)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: Text(current.name, overflow: TextOverflow.ellipsis)),
          const Icon(Icons.arrow_drop_down),
        ]),
      ),
    );
  }
}
