import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../features/admin/admin_home_page.dart';
import '../features/admin/import_page.dart';
import '../features/admin/sermon_page.dart';
import '../features/auth/login_page.dart';
import '../features/home/home_page.dart';
import 'theme.dart';

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const HomePage()),
    GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
    GoRoute(path: '/admin', builder: (_, _) => const AdminHomePage()),
    GoRoute(path: '/admin/sermons/new', builder: (_, _) => const ImportPage()),
    GoRoute(path: '/admin/sermons/:id', builder: (_, state) => SermonPage(sermonId: state.pathParameters['id']!)),
  ],
);

class SelahApp extends StatelessWidget {
  const SelahApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Selah',
        debugShowCheckedModeBanner: false,
        theme: selahTheme(),
        routerConfig: _router,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      );
}
