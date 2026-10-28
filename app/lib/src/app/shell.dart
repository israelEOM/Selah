import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../data/current_church.dart';
import '../data/providers.dart';
import '../features/welcome/welcome_state.dart';
import 'theme.dart';

/// Which tab a location belongs to: Hoy (0), Estudios (1) or Perfil (2).
int tabIndexFor(String location) {
  if (location.startsWith('/c/')) return 1;
  if (location == '/profile' || location.startsWith('/profile/')) return 2;
  return 0;
}

/// The member pages, with the tab bar floating under them.
class SelahShell extends ConsumerStatefulWidget {
  const SelahShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<SelahShell> createState() => _SelahShellState();
}

class _SelahShellState extends ConsumerState<SelahShell> {
  /// The church the Estudios tab last showed, so tapping it again comes back to the same place.
  String? _studiesChurch;

  @override
  void initState() {
    super.initState();
    // A new account that arrives here without passing the sign-in page (the return from Google, an email
    // confirmation link, a restored session) gets the welcome question once per app session.
    ref.listenManual(needsWelcomeProvider, fireImmediately: true, (_, needs) {
      if (needs.value != true) return;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final userId = await ref.read(userIdProvider.future);
        if (!mounted || userId == null || ref.read(welcomeShownProvider).contains(userId)) return;
        markWelcomeShown(ref, userId);
        context.go('/welcome');
      });
    });
  }

  /// Hoy and Perfil switch to their tab; tapping the tab you're on pops it to its root.
  void _goTab(int index) =>
      widget.navigationShell.goBranch(index, initialLocation: index == widget.navigationShell.currentIndex);

  /// Estudios opens the current church, or the church list when there's none.
  Future<void> _openStudies() async {
    String? slug;
    try {
      slug = (await ref.read(currentChurchProvider.future))?.slug;
    } catch (_) {
      slug = null;
    }
    if (!mounted) return;
    if (slug == null) {
      context.push('/churches');
    } else if (slug == _studiesChurch) {
      // Never with initialLocation: that is the branch's placeholder. The branch holds only the church page, so
      // coming back to it is already its root.
      widget.navigationShell.goBranch(1);
    } else {
      context.go('/c/$slug');
    }
  }

  /// Remembers which church the Estudios tab is on.
  void _noteStudiesChurch() {
    if (widget.navigationShell.currentIndex != 1) return;
    final location = widget.navigationShell.shellRouteContext.routerState.uri.path;
    if (tabIndexFor(location) == 1) _studiesChurch = Uri.parse(location).pathSegments[1];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final selected = widget.navigationShell.currentIndex;
    _noteStudiesChurch();
    return Scaffold(
      body: widget.navigationShell,
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
                      onTap: () => _goTab(0),
                    ),
                    _Tab(
                      icon: Icons.menu_book_outlined,
                      label: l.tabStudies,
                      selected: selected == 1,
                      onTap: _openStudies,
                    ),
                    _Tab(
                      icon: Icons.person_outline,
                      label: l.tabProfile,
                      selected: selected == 2,
                      onTap: () => _goTab(2),
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
