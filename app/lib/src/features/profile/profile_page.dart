import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../app/theme_mode.dart';
import '../../data/current_church.dart';
import '../../data/providers.dart';
import '../home/language_menu.dart';

/// The Perfil tab: the person's church, how the app looks, and their account.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final church = ref.watch(currentChurchProvider).value;
    final canEdit = church != null && (ref.watch(churchRoleProvider(church.id)).value?.canEdit ?? false);
    final signedIn = ref.watch(userIdProvider).value != null;
    final platformAdmin = ref.watch(isPlatformAdminProvider).value == true;
    return Scaffold(
      appBar: AppBar(title: Text(l.tabProfile, style: text.titleLarge)),
      body: PageBody(
        children: [
          Eyebrow(l.yourChurch),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(church?.name ?? l.pickChurch, style: text.titleLarge),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    OutlinedButton(
                      onPressed: () => context.push('/churches'),
                      child: Text(church == null ? l.pickChurch : l.changeChurch),
                    ),
                    if (canEdit)
                      OutlinedButton(
                        onPressed: () => context.push('/c/${church.slug}/admin'),
                        child: Text(l.adminArea),
                      ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Eyebrow(l.theme),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(value: ThemeMode.system, label: Text(l.themeSystem)),
              ButtonSegment(value: ThemeMode.light, label: Text(l.themeLight)),
              ButtonSegment(value: ThemeMode.dark, label: Text(l.themeDark)),
            ],
            selected: {ref.watch(themeModeProvider)},
            showSelectedIcon: false,
            onSelectionChanged: (modes) => ref.read(themeModeProvider.notifier).set(modes.single),
          ),
          const SizedBox(height: 32),
          Row(children: [
            Expanded(child: Text(l.language, style: text.bodyLarge)),
            const LanguageMenu(),
          ]),
          const SizedBox(height: 32),
          if (platformAdmin) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l.createChurch),
                onPressed: () => context.push('/churches/new'),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: signedIn
                ? TextButton(onPressed: () => ref.read(repositoryProvider).signOut(), child: Text(l.signOut))
                : FilledButton(
                    onPressed: () => context.push('/login?next=${Uri.encodeQueryComponent('/profile')}'),
                    child: Text(l.signIn),
                  ),
          ),
        ],
      ),
    );
  }
}
