import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../app/theme_mode.dart';
import '../../core/models.dart';
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
    final noChurch = signedIn && ref.watch(myChurchesProvider).value?.isEmpty == true;
    // An approved request needs no line: the church shows up as theirs.
    final shown = signedIn ? ref.watch(myChurchRequestProvider).value : null;
    final request = shown?.status == ChurchRequestStatus.approved ? null : shown;
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
          if (noChurch) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton(onPressed: () => context.push('/welcome?step=member'), child: Text(l.joinAChurch)),
              // Someone waiting on a request, or told to send another, already has their way in above.
              if (!platformAdmin && request == null)
                OutlinedButton(onPressed: () => context.push('/welcome?step=leader'), child: Text(l.bringMyChurch)),
            ]),
          ],
          if (request != null) ...[
            const SizedBox(height: 24),
            Eyebrow(l.yourRequest),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.churchName, style: text.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      request.status == ChurchRequestStatus.pending ? l.requestPending : l.requestRejected,
                      style: text.bodyMedium?.copyWith(color: context.tones.muted),
                    ),
                    if (request.status == ChurchRequestStatus.rejected) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => context.push('/welcome?step=leader'),
                        child: Text(l.sendAnother),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
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
