import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../data/current_church.dart';
import '../data/providers.dart';
import '../features/welcome/welcome_state.dart';
import '../features/church/church_switcher.dart';
import '../features/home/language_menu.dart';
import 'design/adaptive_tab_bar.dart';
import 'theme.dart';

/// Which branch a location belongs to: Hoy (0), Estudios (1), Eventos (2) or Perfil (3).
int tabIndexFor(String location) {
  if (RegExp(r'^/c/[^/]+/events/?$').hasMatch(location)) return 2;
  if (location.startsWith('/c/')) return 1;
  if (location == '/profile' || location.startsWith('/profile/')) return 3;
  return 0;
}

/// Whether the current church has something coming up, so the Eventos tab shows.
final showEventsTabProvider = Provider<bool>((ref) {
  final church = ref.watch(currentChurchProvider).value;
  if (church == null) return false;
  final now = DateTime.now();
  return ref.watch(upcomingEventsProvider(church.id)).value?.any((e) => e.endsAt.isAfter(now)) ?? false;
});

/// The church (a menu when the person belongs to several) and the language, on the right of the website header.
class SiteHeaderTrailing extends ConsumerWidget {
  const SiteHeaderTrailing({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final church = ref.watch(currentChurchProvider).value;
    final memberships = ref.watch(myChurchesProvider).value ?? const [];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (church != null)
          memberships.length > 1
              ? ChurchSwitcher(current: church, admin: false)
              : Flexible(
                  child: Text(church.name, style: Theme.of(context).textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
        const SizedBox(width: Space.s),
        const LanguageMenu(),
      ],
    );
  }
}

/// Goes to a tab's page from outside the shell (the study page and reader): Hoy (0), the current church's
/// studies (1) or events (2), or Perfil (3). With no current church, the studies and events go to the list.
Future<void> goToBranch(BuildContext context, WidgetRef ref, int branch) async {
  if (branch == 0) return context.go('/');
  if (branch == 3) return context.go('/profile');
  String? slug;
  try {
    slug = (await ref.read(currentChurchProvider.future))?.slug;
  } catch (_) {
    slug = null;
  }
  if (!context.mounted) return;
  if (slug == null) {
    context.push('/churches');
  } else {
    context.go(branch == 1 ? '/c/$slug' : '/c/$slug/events');
  }
}

/// The tabs shown, as (branch, tab) in order: Eventos only while there are events or while it's open.
List<(int, SelahTab)> visibleTabs(WidgetRef ref, AppLocalizations l, {required int current}) {
  final events = ref.watch(showEventsTabProvider) || current == 2;
  final all = _allTabs(l);
  return [for (final b in [0, 1, if (events) 2, 3]) (b, all[b])];
}

/// Every tab, by branch: Hoy, Estudios, Eventos and Perfil.
List<SelahTab> _allTabs(AppLocalizations l) => [
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
    label: l.tabEvents,
    icon: Icons.event_outlined,
    selectedIcon: Icons.event,
    symbol: 'calendar',
    selectedSymbol: 'calendar',
  ),
  SelahTab(
    label: l.tabProfile,
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    symbol: 'person',
    selectedSymbol: 'person.fill',
  ),
];

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

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Coming back after a while: read the church's events again, so the Eventos tab reflects what's coming up now.
    _lifecycle = AppLifecycleListener(onResume: () {
      final church = ref.read(currentChurchProvider).value;
      if (church != null) ref.invalidate(upcomingEventsProvider(church.id));
    });
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

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Hoy and Perfil switch to their tab; tapping the tab you're on pops it to its root.
  void _goTab(int index) =>
      widget.navigationShell.goBranch(index, initialLocation: index == widget.navigationShell.currentIndex);

  /// Eventos opens the current church's events.
  Future<void> _openEvents() async {
    final church = await ref.read(currentChurchProvider.future);
    if (!mounted || church == null) return;
    final target = '/c/${church.slug}/events';
    if (widget.navigationShell.shellRouteContext.routerState.uri.path == target) return;
    context.go(target);
  }

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

  void _selectBranch(int branch) => switch (branch) {
        1 => _openStudies(),
        2 => _openEvents(),
        _ => _goTab(branch),
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final visible = visibleTabs(ref, l, current: widget.navigationShell.currentIndex);
    final branches = [for (final (b, _) in visible) b];
    final selected = branches.indexOf(widget.navigationShell.currentIndex);
    _noteStudiesChurch();
    final tabs = [for (final (_, tab) in visible) tab];
    void select(int index) => _selectBranch(branches[index]);
    final site = siteLayout(context);
    // One tree for both layouts, so crossing 1024 px moves nothing and every tab keeps its stack. The page runs
    // under the floating bar, and its bottom inset grows by the bar's height so the last item still clears it.
    return Scaffold(
      extendBody: !site,
      body: Column(
        children: [
          if (site)
            SiteHeader(
              tabs: tabs,
              selected: selected,
              onSelect: select,
              trailing: const SiteHeaderTrailing(),
            )
          else
            const SizedBox.shrink(),
          Expanded(child: widget.navigationShell),
        ],
      ),
      bottomNavigationBar: site ? null : AdaptiveTabBar(tabs: tabs, currentIndex: selected, onTap: select),
    );
  }
}
