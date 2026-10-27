import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/features/church/church_page.dart';
import 'package:selah/src/features/home/home_page.dart';

const _church = Church(id: 'A', slug: 'vida-nueva', name: 'Iglesia Vida Nueva');

Future<void> _pump(WidgetTester tester, {String? userId, ChurchRole? role}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      userIdProvider.overrideWith((ref) => Stream.value(userId)),
      myChurchesProvider.overrideWith((ref) async => [if (role != null) Membership(church: _church, role: role)]),
      publicChurchesProvider.overrideWith((ref) async => const []),
    ],
    child: MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomePage(),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _pumpRouter(WidgetTester tester, GoRouter router, {ChurchRole? role}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      userIdProvider.overrideWith((ref) => Stream.value(null)),
      myChurchesProvider.overrideWith((ref) async => const []),
      churchRoleProvider('A').overrideWith((ref) async => role),
      publicChurchesProvider.overrideWith((ref) async => const [_church]),
      publishedStudiesProvider('A').overrideWith((ref) async => const [
            StudyCard(id: '1', slug: 'retiro-espiritual', title: 'La necesidad del retiro espiritual', numberOfDays: 3),
          ]),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a visitor sees sign in', (tester) async {
    await _pump(tester);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('a signed-in member sees sign out instead of sign in', (tester) async {
    await _pump(tester, userId: 'user-1', role: ChurchRole.member);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsNothing);
    expect(find.text('Administrar'), findsNothing);
  });

  testWidgets('someone who edits a church sees the admin link', (tester) async {
    await _pump(tester, userId: 'user-1', role: ChurchRole.editor);
    expect(find.text('Administrar'), findsOneWidget);
  });

  testWidgets('tapping a church opens it', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const HomePage()),
      GoRoute(path: '/c/:church', builder: (_, s) => Text('CHURCH ${s.pathParameters['church']}')),
    ]);
    await _pumpRouter(tester, router);
    await tester.tap(find.text('Iglesia Vida Nueva'));
    await tester.pumpAndSettle();
    expect(find.text('CHURCH vida-nueva'), findsOneWidget);
  });

  testWidgets('a church page lists its studies and opens one', (tester) async {
    final router = GoRouter(initialLocation: '/c/vida-nueva', routes: [
      GoRoute(path: '/c/vida-nueva', builder: (_, _) => const ChurchPage(church: _church)),
      GoRoute(
        path: '/c/vida-nueva/studies/:slug',
        builder: (_, s) => Text('STUDY ${s.pathParameters['slug']}'),
      ),
    ]);
    await _pumpRouter(tester, router);
    expect(find.text('Iglesia Vida Nueva'), findsOneWidget);
    expect(find.text('Administrar'), findsNothing);
    await tester.tap(find.text('La necesidad del retiro espiritual'));
    await tester.pumpAndSettle();
    expect(find.text('STUDY retiro-espiritual'), findsOneWidget);
  });

  testWidgets('a church page offers admin to its editors', (tester) async {
    final router = GoRouter(initialLocation: '/c/vida-nueva', routes: [
      GoRoute(path: '/c/vida-nueva', builder: (_, _) => const ChurchPage(church: _church)),
    ]);
    await _pumpRouter(tester, router, role: ChurchRole.editor);
    expect(find.text('Administrar'), findsOneWidget);
  });
}
