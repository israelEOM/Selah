import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../features/admin/admin_home_page.dart';
import '../features/admin/church_settings_page.dart';
import '../features/admin/import_page.dart';
import '../features/admin/people_page.dart';
import '../features/admin/requests_page.dart';
import '../features/admin/sermon_page.dart';
import '../core/models.dart';
import '../features/auth/login_page.dart';
import '../features/church/church_page.dart';
import '../features/church/church_scope.dart';
import '../features/church/create_church_page.dart';
import '../features/church/join_page.dart';
import '../features/church/legacy_redirects.dart';
import '../features/home/church_picker_page.dart';
import '../features/profile/profile_page.dart';
import '../features/study/reader_page.dart';
import '../features/study/study_page.dart';
import '../features/today/today_page.dart';
import '../features/welcome/welcome_page.dart';
import '../l10n/locale.dart';
import 'design/adaptive_tab_bar.dart';
import 'shell.dart';
import 'theme.dart';
import 'theme_mode.dart';

/// Admin screens are always Spanish, whatever language the member picked.
Widget inSpanish(BuildContext context, Widget page) =>
    Localizations.override(context: context, locale: const Locale('es'), child: page);

/// A page under `/c/:church`, built once the church in the address has loaded.
Widget _inChurch(GoRouterState state, Widget Function(Church church) builder) =>
    ChurchScope(slug: state.pathParameters['church']!, builder: builder);

/// An admin page under `/c/:church/admin`, always in Spanish.
Widget _inChurchAdmin(BuildContext context, GoRouterState state, Widget Function(Church church) builder) =>
    inSpanish(context, _inChurch(state, builder));

/// The app's top navigator, which the study page and the reader open on, above the tab bar.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// A route whose page is a Flutter [MaterialPage], so it gets the platform transition and its back gestures: the
/// iOS edge swipe and Android predictive back. go_router 18 checks for package:material_ui's MaterialApp rather
/// than Flutter's, so left to itself it builds every page as a [NoTransitionPage], with neither.
GoRoute _page({
  required String path,
  required GoRouterWidgetBuilder builder,
  GlobalKey<NavigatorState>? parentNavigatorKey,
}) => GoRoute(
  path: path,
  parentNavigatorKey: parentNavigatorKey,
  pageBuilder: (_, state) => MaterialPage<void>(
    key: state.pageKey,
    name: state.name ?? state.path,
    arguments: {...state.pathParameters, ...state.uri.queryParameters},
    restorationId: state.pageKey.value,
    child: Builder(builder: (context) => builder(context, state)),
  ),
);

GoRouter createRouter({String initialLocation = '/'}) {
  // On web, the address bar shows the page on top, pushed or not, so it can be copied and reopened.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: initialLocation,
      // Hides the native glass bar while a page opens above the tabs.
      observers: [CNTabBarRouteObserver()],
      routes: [
        // The three tab roots, each with its own stack, under the tab bar.
        StatefulShellRoute.indexedStack(
          // A MaterialPage too (see _page), so the tabs slide aside under a page pushed above them.
          pageBuilder: (_, state, navigationShell) => MaterialPage<void>(
            key: state.pageKey,
            restorationId: state.pageKey.value,
            child: SelahShell(navigationShell: navigationShell),
          ),
          branches: [
            StatefulShellBranch(routes: [_page(path: '/', builder: (_, _) => const TodayPage())]),
            StatefulShellBranch(
              // go_router wants a location it can open on its own. Estudios never uses it: the tab goes to a real
              // church first and never calls goBranch with initialLocation (see SelahShell), so this placeholder
              // is never built.
              initialLocation: '/c/_',
              routes: [
                _page(path: '/c/:church', builder: (_, state) => _inChurch(state, (church) => ChurchPage(church: church))),
              ],
            ),
            StatefulShellBranch(routes: [_page(path: '/profile', builder: (_, _) => const ProfilePage())]),
          ],
        ),
        // Reading sits above the tabs, so back returns to whichever tab opened it.
        _page(
          path: '/c/:church/studies/:slug',
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, state) => _inChurch(state, (church) => StudyPage(church: church, slug: state.pathParameters['slug']!)),
        ),
        _page(
          path: '/c/:church/studies/:slug/day/:number',
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, state) => _inChurch(
            state,
            (church) => ReaderPage(
              church: church,
              slug: state.pathParameters['slug']!,
              dayNumber: int.tryParse(state.pathParameters['number']!) ?? 0,
            ),
          ),
        ),
        _page(path: '/churches', builder: (_, _) => const ChurchPickerPage()),
        _page(path: '/login', builder: (_, _) => const LoginPage()),
        _page(path: '/welcome', builder: (_, state) => WelcomePage(step: state.uri.queryParameters['step'])),
        _page(path: '/join/:token', builder: (_, state) => JoinPage(token: state.pathParameters['token']!)),
        _page(path: '/churches/new', builder: (_, _) => const CreateChurchPage()),
        _page(path: '/requests', builder: (context, _) => inSpanish(context, const RequestsPage())),
        _page(
          path: '/c/:church/admin',
          builder: (context, state) => _inChurchAdmin(context, state, (church) => AdminHomePage(church: church)),
        ),
        _page(
          path: '/c/:church/admin/settings',
          builder: (context, state) => _inChurchAdmin(context, state, (church) => ChurchSettingsPage(church: church)),
        ),
        _page(
          path: '/c/:church/admin/people',
          builder: (context, state) => _inChurchAdmin(context, state, (church) => PeoplePage(church: church)),
        ),
        _page(
          path: '/c/:church/admin/sermons/new',
          builder: (context, state) => _inChurchAdmin(context, state, (church) => ImportPage(church: church)),
        ),
        _page(
          path: '/c/:church/admin/sermons/:id',
          builder: (context, state) => _inChurchAdmin(
            context,
            state,
            (church) => SermonPage(church: church, sermonId: state.pathParameters['id']!),
          ),
        ),
        // Links from before churches had their own addresses.
        _page(path: '/studies/:slug', builder: (_, state) => LegacyStudyRedirect(slug: state.pathParameters['slug']!)),
        _page(
          path: '/studies/:slug/day/:number',
          builder: (_, state) => LegacyStudyRedirect(
            slug: state.pathParameters['slug']!,
            dayNumber: state.pathParameters['number']!,
          ),
        ),
        _page(path: '/admin', builder: (_, _) => const LegacyAdminRedirect()),
      ],
    );
}

final _router = createRouter();

class SelahApp extends ConsumerWidget {
  const SelahApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'Selah',
        debugShowCheckedModeBanner: false,
        theme: selahLightTheme(),
        darkTheme: selahDarkTheme(),
        themeMode: ref.watch(themeModeProvider),
        routerConfig: _router,
        locale: ref.watch(appLocaleProvider),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      );
}
