import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../features/admin/admin_home_page.dart';
import '../features/admin/import_page.dart';
import '../features/admin/sermon_page.dart';
import '../features/auth/login_page.dart';
import '../features/home/home_page.dart';
import '../features/study/reader_page.dart';
import '../features/study/study_page.dart';
import '../l10n/locale.dart';
import 'theme.dart';

/// Admin screens are always Spanish, whatever language the member picked.
Widget inSpanish(BuildContext context, Widget page) =>
    Localizations.override(context: context, locale: const Locale('es'), child: page);

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const HomePage()),
    GoRoute(path: '/studies/:slug', builder: (_, state) => StudyPage(slug: state.pathParameters['slug']!)),
    GoRoute(
      path: '/studies/:slug/day/:number',
      builder: (_, state) => ReaderPage(
        slug: state.pathParameters['slug']!,
        dayNumber: int.tryParse(state.pathParameters['number']!) ?? 0,
      ),
    ),
    GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
    GoRoute(path: '/admin', builder: (context, _) => inSpanish(context, const AdminHomePage())),
    GoRoute(path: '/admin/sermons/new', builder: (context, _) => inSpanish(context, const ImportPage())),
    GoRoute(path: '/admin/sermons/:id', builder: (context, state) => inSpanish(context, SermonPage(sermonId: state.pathParameters['id']!))),
  ],
);

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
