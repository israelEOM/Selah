import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../data/providers.dart';

class AdminHomePage extends ConsumerWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final userId = ref.watch(userIdProvider);
    final isAdmin = ref.watch(isAdminProvider);

    if (userId.isLoading || isAdmin.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final signedIn = userId.value != null;
    if (!(isAdmin.value ?? false)) {
      return Scaffold(
        appBar: AppBar(),
        body: PageBody(maxWidth: 440, children: [
          Text(l.adminOnly, style: text.bodyLarge),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              if (signedIn) await ref.read(repositoryProvider).signOut();
              if (context.mounted) context.go(signedIn ? '/' : '/login');
            },
            child: Text(signedIn ? l.signOut : l.signIn),
          ),
        ]),
      );
    }

    final sermons = ref.watch(sermonsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/')),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(repositoryProvider).signOut();
              if (context.mounted) context.go('/');
            },
            child: Text(l.signOut),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PageBody(maxWidth: 900, children: [
        Eyebrow(l.admin),
        const SizedBox(height: 8),
        Text(l.adminTitle, style: text.headlineMedium),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: Tooltip(
            message: l.comingSoon,
            child: FilledButton(onPressed: null, child: Text(l.importSermon)),
          ),
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
                        child: ListTile(
                          title: Text(sermon.title, style: text.titleLarge),
                          subtitle: sermon.studyStatus == null ? null : Text(sermon.studyStatus!.toUpperCase()),
                        ),
                      ),
                    ),
                ],
        ),
      ]),
    );
  }
}
