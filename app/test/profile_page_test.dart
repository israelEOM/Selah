import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/app/theme.dart';
import 'package:selah/src/app/theme_mode.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/current_church.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/features/profile/profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _vida = Church(id: 'A', slug: 'vida-nueva', name: 'Iglesia Vida Nueva');

Future<void> _pump(WidgetTester tester, {String? userId, ChurchRole? role, bool platformAdmin = false}) async {
  SharedPreferences.setMockInitialValues({});
  final router = GoRouter(initialLocation: '/profile', routes: [
    GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
    GoRoute(path: '/churches', builder: (_, _) => const Text('PICKER')),
    GoRoute(path: '/churches/new', builder: (_, _) => const Text('NEW CHURCH')),
    GoRoute(path: '/c/vida-nueva/admin', builder: (_, _) => const Text('ADMIN')),
    GoRoute(path: '/login', builder: (_, s) => Text('LOGIN ${s.uri.queryParameters['next']}')),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      userIdProvider.overrideWith((ref) => Stream.value(userId)),
      currentChurchProvider.overrideWith((ref) async => _vida),
      churchRoleProvider('A').overrideWith((ref) async => role),
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

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the current church and a way to change it', (tester) async {
    await _pump(tester);
    expect(find.text('Iglesia Vida Nueva'), findsOneWidget);
    await _tap(tester, 'Cambiar de iglesia');
    expect(find.text('PICKER'), findsOneWidget);
  });

  testWidgets('choosing Oscuro switches to the dark theme', (tester) async {
    await _pump(tester);
    await _tap(tester, 'Oscuro');
    final container = ProviderScope.containerOf(tester.element(find.byType(ProfilePage)));
    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect((await SharedPreferences.getInstance()).getString('theme'), 'dark');
  });

  testWidgets('an editor can open the church admin', (tester) async {
    await _pump(tester, userId: 'u', role: ChurchRole.editor);
    await _tap(tester, 'Administrar la iglesia');
    expect(find.text('ADMIN'), findsOneWidget);
  });

  testWidgets('a member is not offered the church admin', (tester) async {
    await _pump(tester, userId: 'u', role: ChurchRole.member);
    expect(find.text('Administrar la iglesia'), findsNothing);
  });

  testWidgets('signed out offers sign in and comes back here', (tester) async {
    await _pump(tester);
    expect(find.text('Cerrar sesión'), findsNothing);
    await _tap(tester, 'Iniciar sesión');
    expect(find.text('LOGIN /profile'), findsOneWidget);
  });

  testWidgets('signed in offers sign out', (tester) async {
    await _pump(tester, userId: 'u', role: ChurchRole.member);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsNothing);
  });

  testWidgets('an owner who is not a platform admin is not offered to create a church', (tester) async {
    await _pump(tester, userId: 'u', role: ChurchRole.owner);
    expect(find.text('Crear una iglesia'), findsNothing);
  });

  testWidgets('a platform admin creating a church goes to the form', (tester) async {
    await _pump(tester, userId: 'u', platformAdmin: true);
    await _tap(tester, 'Crear una iglesia');
    expect(find.text('NEW CHURCH'), findsOneWidget);
  });
}
