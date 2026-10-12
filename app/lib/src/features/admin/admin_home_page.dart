import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../data/providers.dart';
import 'admin_gate.dart';

class AdminHomePage extends ConsumerWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final sermons = ref.watch(sermonsProvider);
    return AdminPage(backTo: '/', children: [
      Eyebrow(l.admin),
      const SizedBox(height: 8),
      Text(l.adminTitle, style: text.headlineMedium),
      const SizedBox(height: 20),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton(onPressed: () => context.go('/admin/sermons/new'), child: Text(l.importSermon)),
      ),
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
                        title: Text(sermon.title, style: text.titleLarge),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Eyebrow(studyStatusLabel(l, sermon.studyStatus)),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go('/admin/sermons/${sermon.id}'),
                      ),
                    ),
                  ),
              ],
      ),
    ]);
  }
}
