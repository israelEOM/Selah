import 'package:flutter/material.dart';
import 'package:selah/src/app/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/features/home/home_page.dart';

const _vida = Church(id: 'A', slug: 'vida-nueva', name: 'Iglesia Vida Nueva');
const _otra = Church(id: 'B', slug: 'otra', name: 'Otra Iglesia');

Future<void> _pump(WidgetTester tester, {String? userId, ChurchRole? role, bool platformAdmin = false}) async {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => const HomePage()),
    GoRoute(path: '/c/:church', builder: (_, s) => Text('CHURCH ${s.pathParameters['church']}')),
    GoRoute(path: '/churches/new', builder: (_, _) => const Text('NEW CHURCH')),
    GoRoute(path: '/login', builder: (_, s) => Text('LOGIN ${s.uri.queryParameters['next']}')),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      userIdProvider.overrideWith((ref) => Stream.value(userId)),
      myChurchesProvider.overrideWith((ref) async => [if (role != null) Membership(church: _vida, role: role)]),
      publicChurchesProvider.overrideWith((ref) async => const [_vida, _otra]),
      isPlatformAdminProvider.overrideWith((ref) async => platformAdmin),
    ],
    child: MaterialApp.router(
      theme: selahLightTheme(),
      routerConfig: router,
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a visitor sees the public churches and sign in', (tester) async {
    await _pump(tester);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('TUS IGLESIAS'), findsNothing);
    expect(find.text('Iglesia Vida Nueva'), findsOneWidget);
    expect(find.text('Otra Iglesia'), findsOneWidget);
  });

  testWidgets('tapping a church opens it', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Otra Iglesia'));
    await tester.pumpAndSettle();
    expect(find.text('CHURCH otra'), findsOneWidget);
  });

  testWidgets('a signed-in member sees their churches with the role', (tester) async {
    await _pump(tester, userId: 'user-1', role: ChurchRole.editor);
    expect(find.text('TUS IGLESIAS'), findsOneWidget);
    expect(find.text('Editor'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsNothing);
  });

  testWidgets('visitors and signed-in non-admins are not offered to create a church', (tester) async {
    await _pump(tester);
    expect(find.text('Crear una iglesia'), findsNothing);
    await _pump(tester, userId: 'user-1', role: ChurchRole.owner);
    expect(find.text('Crear una iglesia'), findsNothing);
  });

  testWidgets('a platform admin creating a church goes to the form', (tester) async {
    await _pump(tester, userId: 'user-1', platformAdmin: true);
    await tester.ensureVisible(find.text('Crear una iglesia'));
    await tester.tap(find.text('Crear una iglesia'));
    await tester.pumpAndSettle();
    expect(find.text('NEW CHURCH'), findsOneWidget);
  });
}
