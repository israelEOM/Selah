import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../data/current_church.dart';
import 'theme.dart';

/// Which tab a location belongs to: Hoy (0), Estudios (1) or Perfil (2).
int tabIndexFor(String location) {
  if (location.startsWith('/c/')) return 1;
  if (location == '/profile' || location.startsWith('/profile/')) return 2;
  return 0;
}

/// The member pages, with the tab bar floating under them.
class SelahShell extends ConsumerWidget {
  const SelahShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final selected = tabIndexFor(location);
    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Align(
            heightFactor: 1,
            child: ConstrainedBox(
              // The width of PageBody's content.
              constraints: const BoxConstraints(maxWidth: 720),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.tones.surface,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(children: [
                    _Tab(
                      icon: Icons.wb_sunny_outlined,
                      label: l.tabToday,
                      selected: selected == 0,
                      onTap: () => context.go('/'),
                    ),
                    _Tab(
                      icon: Icons.menu_book_outlined,
                      label: l.tabStudies,
                      selected: selected == 1,
                      onTap: () async {
                        final church = await ref.read(currentChurchProvider.future);
                        if (!context.mounted) return;
                        context.go(church == null ? '/churches' : '/c/${church.slug}');
                      },
                    ),
                    _Tab(
                      icon: Icons.person_outline,
                      label: l.tabProfile,
                      selected: selected == 2,
                      onTap: () => context.go('/profile'),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final color = selected ? primary : context.tones.muted;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: selected ? primary.withValues(alpha: 0.12) : Colors.transparent,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: color),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
