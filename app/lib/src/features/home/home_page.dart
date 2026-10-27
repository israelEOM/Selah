import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../data/providers.dart';
import 'language_menu.dart';

/// The front door: churches that have published studies.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final churches = ref.watch(publicChurchesProvider);
    final editsAny = ref.watch(myChurchesProvider).value?.any((m) => m.role.canEdit) ?? false;
    final signedIn = ref.watch(userIdProvider).value != null;
    return Scaffold(
      appBar: AppBar(
        title: Text('Selah.', style: text.headlineMedium),
        actions: [
          const LanguageMenu(),
          if (editsAny)
            TextButton(onPressed: () => context.push('/admin'), child: Text(l.admin))
          else if (signedIn)
            TextButton(onPressed: () => ref.read(repositoryProvider).signOut(), child: Text(l.signOut))
          else
            TextButton(onPressed: () => context.push('/login'), child: Text(l.signIn)),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(publicChurchesProvider.future),
        child: PageBody(
          children: [
            const SizedBox(height: 16),
            Eyebrow(l.heroEyebrow),
            const SizedBox(height: 12),
            Text('${l.tagline}.', style: text.displaySmall),
            const SizedBox(height: 36),
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
                  : [
                      for (final church in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              title: Text(church.name, style: text.titleLarge),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push('/c/${church.slug}'),
                            ),
                          ),
                        ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}
