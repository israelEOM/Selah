import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../features/admin/admin_home_page.dart';
import '../features/admin/import_page.dart';
import '../features/admin/sermon_page.dart';
import '../core/models.dart';
import '../features/auth/login_page.dart';
import '../features/church/church_page.dart';
import '../features/church/church_scope.dart';
import '../features/church/legacy_redirects.dart';
import '../features/home/home_page.dart';
import '../features/study/reader_page.dart';
import '../features/study/study_page.dart';
import '../l10n/locale.dart';
import 'theme.dart';

/// Admin screens are always Spanish, whatever language the member picked.
Widget inSpanish(BuildContext context, Widget page) =>
    Localizations.override(context: context, locale: const Locale('es'), child: page);

/// A page under `/c/:church`, built once the church in the address has loaded.
Widget _inChurch(GoRouterState state, Widget Function(Church church) builder) =>
    ChurchScope(slug: state.pathParameters['church']!, builder: builder);

/// An admin page under `/c/:church/admin`, always in Spanish.
Widget _inChurchAdmin(BuildContext context, GoRouterState state, Widget Function(Church church) builder) =>
    inSpanish(context, _inChurch(state, builder));

GoRouter createRouter({String initialLocation = '/'}) => GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomePage()),
        GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
        GoRoute(path: '/c/:church', builder: (_, state) => _inChurch(state, (church) => ChurchPage(church: church))),
        GoRoute(
          path: '/c/:church/studies/:slug',
          builder: (_, state) =>
              _inChurch(state, (church) => StudyPage(church: church, slug: state.pathParameters['slug']!)),
        ),
        GoRoute(
          path: '/c/:church/studies/:slug/day/:number',
          builder: (_, state) => _inChurch(
            state,
            (church) => ReaderPage(
              church: church,
              slug: state.pathParameters['slug']!,
              dayNumber: int.tryParse(state.pathParameters['number']!) ?? 0,
            ),
          ),
        ),
        GoRoute(
          path: '/c/:church/admin',
          builder: (context, state) => _inChurchAdmin(context, state, (church) => AdminHomePage(church: church)),
        ),
        GoRoute(
          path: '/c/:church/admin/sermons/new',
          builder: (context, state) => _inChurchAdmin(context, state, (church) => ImportPage(church: church)),
        ),
        GoRoute(
          path: '/c/:church/admin/sermons/:id',
          builder: (context, state) => _inChurchAdmin(
            context,
            state,
            (church) => SermonPage(church: church, sermonId: state.pathParameters['id']!),
          ),
        ),
        // Links from before churches had their own addresses.
        GoRoute(path: '/studies/:slug', builder: (_, state) => LegacyStudyRedirect(slug: state.pathParameters['slug']!)),
        GoRoute(
          path: '/studies/:slug/day/:number',
          builder: (_, state) => LegacyStudyRedirect(
            slug: state.pathParameters['slug']!,
            dayNumber: state.pathParameters['number']!,
          ),
        ),
        GoRoute(path: '/admin', builder: (_, _) => const LegacyAdminRedirect()),
      ],
    );

final _router = createRouter();

class SelahApp extends ConsumerWidget {
  const SelahApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'Selah',
        debugShowCheckedModeBanner: false,
        theme: selahTheme(),
        routerConfig: _router,
        locale: ref.watch(appLocaleProvider),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      );
}
