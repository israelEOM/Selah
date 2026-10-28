import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../data/current_church.dart';
import '../data/providers.dart';
import '../features/welcome/welcome_state.dart';
import 'design/adaptive_tab_bar.dart';
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

  /// Hoy, Estudios and Perfil, in tab order.
  List<SelahTab> _tabs(AppLocalizations l) => [
    SelahTab(
      label: l.tabToday,
      icon: Icons.wb_sunny_outlined,
      selectedIcon: Icons.wb_sunny,
      symbol: 'sun.max',
      selectedSymbol: 'sun.max.fill',
    ),
    SelahTab(
      label: l.tabStudies,
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book,
      symbol: 'book',
      selectedSymbol: 'book.fill',
    ),
    SelahTab(
      label: l.tabProfile,
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      symbol: 'person',
      selectedSymbol: 'person.fill',
    ),
  ];

  void _select(int index) => index == 1 ? _openStudies() : _goTab(index);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final selected = widget.navigationShell.currentIndex;
    _noteStudiesChurch();
    final tabs = _tabs(l);
    final wide = uiPlatformOf(context) != UiPlatform.ios && MediaQuery.sizeOf(context).width >= kRailBreakpoint;
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: selected,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (index) {
              SelahHaptics.selection();
              _select(index);
            },
            destinations: [
              for (final tab in tabs)
                NavigationRailDestination(
                  icon: Icon(tab.icon),
                  selectedIcon: Icon(tab.selectedIcon),
                  label: Text(tab.label),
                ),
            ],
          ),
          Expanded(child: widget.navigationShell),
        ]),
      );
    }
    // The page runs under the bar, and its bottom inset grows by the bar's height so the last item still clears it.
    return Scaffold(
      extendBody: true,
      body: widget.navigationShell,
      bottomNavigationBar: AdaptiveTabBar(tabs: tabs, currentIndex: selected, onTap: _select),
    );
  }
}
