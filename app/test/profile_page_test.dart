import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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

Future<void> _pump(
  WidgetTester tester, {
  String? userId,
  ChurchRole? role,
  bool platformAdmin = false,
  List<Membership>? mine,
  ChurchRequest? request,
}) async {
  SharedPreferences.setMockInitialValues({});
  final router = GoRouter(initialLocation: '/profile', routes: [
    GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
    GoRoute(path: '/churches', builder: (_, _) => const Text('PICKER')),
    GoRoute(path: '/churches/new', builder: (_, _) => const Text('NEW CHURCH')),
    GoRoute(path: '/c/vida-nueva/admin', builder: (_, _) => const Text('ADMIN')),
    GoRoute(path: '/welcome', builder: (_, s) => Text('WELCOME ${s.uri.queryParameters['step']}')),
    GoRoute(path: '/login', builder: (_, s) => Text('LOGIN ${s.uri.queryParameters['next']}')),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      userIdProvider.overrideWith((ref) => Stream.value(userId)),
      currentChurchProvider.overrideWith((ref) async => _vida),
      churchRoleProvider('A').overrideWith((ref) async => role),
      isPlatformAdminProvider.overrideWith((ref) async => platformAdmin),
      if (mine != null) myChurchesProvider.overrideWith((ref) async => mine),
      if (request != null) myChurchRequestProvider.overrideWith((ref) async => request),
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

  ChurchRequest requestWith(ChurchRequestStatus status) =>
      ChurchRequest(id: 'r1', churchName: 'Iglesia Roca', status: status, createdAt: DateTime(2026, 10, 27));

  testWidgets('a rejected request offers Enviar otra', (tester) async {
    await _pump(tester, userId: 'u', mine: const [], request: requestWith(ChurchRequestStatus.rejected));
    expect(find.text('Tu solicitud no fue aprobada'), findsOneWidget);
    await _tap(tester, 'Enviar otra');
    expect(find.text('WELCOME leader'), findsOneWidget);
  });

  testWidgets('a pending request shows Pendiente de aprobación', (tester) async {
    await _pump(tester, userId: 'u', mine: const [], request: requestWith(ChurchRequestStatus.pending));
    expect(find.text('TU SOLICITUD'), findsOneWidget);
    expect(find.text('Pendiente de aprobación'), findsOneWidget);
    expect(find.text('Traer mi iglesia a Selah'), findsNothing);
  });

  testWidgets('an approved request shows nothing', (tester) async {
    await _pump(tester, userId: 'u', mine: const [], request: requestWith(ChurchRequestStatus.approved));
    expect(find.text('TU SOLICITUD'), findsNothing);
  });

  testWidgets('someone with no church can join one', (tester) async {
    await _pump(tester, userId: 'u', mine: const []);
    await _tap(tester, 'Unirme a una iglesia');
    expect(find.text('WELCOME member'), findsOneWidget);
  });

  testWidgets('someone with no church can ask to bring theirs', (tester) async {
    await _pump(tester, userId: 'u', mine: const []);
    await _tap(tester, 'Traer mi iglesia a Selah');
    expect(find.text('WELCOME leader'), findsOneWidget);
  });

  testWidgets('a member is not offered to join or bring a church', (tester) async {
    await _pump(tester, userId: 'u', role: ChurchRole.member, mine: const [Membership(church: _vida, role: ChurchRole.member)]);
    expect(find.text('Unirme a una iglesia'), findsNothing);
    expect(find.text('Traer mi iglesia a Selah'), findsNothing);
  });

  testWidgets('profile theme picker is the sliding control on iOS', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await _pump(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(CupertinoSlidingSegmentedControl<ThemeMode>), findsOneWidget);
      await _tap(tester, 'Oscuro');
      final container = ProviderScope.containerOf(tester.element(find.byType(ProfilePage)));
      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect((await SharedPreferences.getInstance()).getString('theme'), 'dark');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
