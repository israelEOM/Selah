import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../data/providers.dart';

/// Frame for every admin screen. Shows the content only to admins; the database
/// enforces the same rule, this just gives everyone else a clear message.
class AdminPage extends ConsumerWidget {
  const AdminPage({super.key, required this.backTo, required this.children, this.maxWidth = 900});

  final String backTo;
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
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
          Text(l.adminOnly, style: Theme.of(context).textTheme.bodyLarge),
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), tooltip: l.back, onPressed: () => context.go(backTo)),
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
      body: PageBody(maxWidth: maxWidth, children: children),
    );
  }
}

String studyStatusLabel(AppLocalizations l, String? status) => switch (status) {
      'published' => l.statusPublished,
      'review' => l.statusReview,
      'generating' => l.statusGenerating,
      _ => l.statusDraft,
    };
