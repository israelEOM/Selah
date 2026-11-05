import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/app/app.dart';
import 'package:selah/src/app/shell.dart';
import 'package:selah/src/app/theme.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/current_church.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/data/repository.dart';
import 'package:selah/src/features/welcome/welcome_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _vida = Church(id: 'A', slug: 'vida-nueva', name: 'Iglesia Vida Nueva');

final _meeting = ChurchEvent(
  uid: 'm1',
  title: 'Reunión de jóvenes',
  startsAt: DateTime.utc(2026, 11, 21, 17),
  endsAt: DateTime.utc(2026, 11, 21, 19),
  localStart: DateTime(2026, 11, 21, 18),
  localEnd: DateTime(2026, 11, 21, 20),
);

class _FakeRepository implements SelahRepository {
  _FakeRepository([this.events = const []]);

  final List<ChurchEvent> events;

  @override
  Future<List<ChurchEvent>> upcomingEvents(String churchId) async => events;

  @override
  Future<Church?> churchBySlug(String slug) async => slug == 'vida-nueva' ? _vida : null;

  @override
  Future<List<StudyCard>> publishedStudies(String churchId) async => const [];

  @override
  Future<List<Church>> publicChurches() async => const [_vida];

  @override
  Future<List<SermonRow>> sermons(String churchId) async => const [];

  @override
  Future<ChurchRole?> roleIn(String churchId) async => ChurchRole.editor;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<GoRouter> _pump(WidgetTester tester, String location,
    {Church? current = _vida, bool needsWelcome = false, List<ChurchEvent> events = const []}) async {
  SharedPreferences.setMockInitialValues({});
  final router = createRouter(initialLocation: location);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(_FakeRepository(events)),
      userIdProvider.overrideWith((ref) => Stream.value('user-1')),
      myChurchesProvider.overrideWith((ref) async => const [Membership(church: _vida, role: ChurchRole.editor)]),
      isPlatformAdminProvider.overrideWith((ref) async => false),
      currentChurchProvider.overrideWith((ref) async => current),
      needsWelcomeProvider.overrideWith((ref) async => needsWelcome),
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
  return router;
}

String _path(GoRouter router) => router.state.uri.path;

void main() {
  test('tabIndexFor maps locations to tabs', () {
    expect(tabIndexFor('/'), 0);
    expect(tabIndexFor('/c/x'), 1);
    expect(tabIndexFor('/c/x/studies/s/day/2'), 1);
    expect(tabIndexFor('/c/x/events'), 2);
    expect(tabIndexFor('/profile'), 3);
  });

  testWidgets('the profile page shows Hoy, Estudios and Perfil when there are no events', (tester) async {
    await _pump(tester, '/profile');
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Estudios'), findsOneWidget);
    expect(find.text('Perfil'), findsWidgets);
    expect(find.text('Eventos'), findsNothing);
  });

  testWidgets('Eventos sits between Estudios and Perfil when the church has events', (tester) async {
    final router = await _pump(tester, '/profile', events: [_meeting]);
    double x(String label) => tester.getCenter(find.text(label).last).dx;
    expect(x('Estudios') < x('Eventos') && x('Eventos') < x('Perfil'), isTrue);
    await tester.tap(find.text('Eventos'));
    await tester.pumpAndSettle();
    expect(_path(router), '/c/vida-nueva/events');
    expect(find.text('Reunión de jóvenes'), findsOneWidget);
  });

  testWidgets('without events Perfil still opens the profile', (tester) async {
    final router = await _pump(tester, '/');
    expect(find.text('Eventos'), findsNothing);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(_path(router), '/profile');
  });

  testWidgets('no church, no Eventos tab', (tester) async {
    await _pump(tester, '/profile', current: null, events: [_meeting]);
    expect(find.text('Eventos'), findsNothing);
  });

  testWidgets('Estudios opens the current church', (tester) async {
    final router = await _pump(tester, '/profile');
    await tester.tap(find.text('Estudios'));
    await tester.pumpAndSettle();
    expect(_path(router), '/c/vida-nueva');
  });

  testWidgets('Estudios without a church opens the picker', (tester) async {
    final router = await _pump(tester, '/profile', current: null);
    await tester.tap(find.text('Estudios'));
    await tester.pumpAndSettle();
    expect(_path(router), '/churches');
  });

  testWidgets('Hoy without a church shows the church list', (tester) async {
    await _pump(tester, '/', current: null);
    expect(find.text('Elige tu iglesia'), findsWidgets);
    expect(find.text('Iglesia Vida Nueva'), findsWidgets);
    expect(find.text('Hoy'), findsOneWidget);
  });

  testWidgets('opening a church with none chosen remembers it', (tester) async {
    await _pump(tester, '/c/vida-nueva');
    expect((await SharedPreferences.getInstance()).getString('church'), 'vida-nueva');
  });

  testWidgets('admin pages have no tab bar', (tester) async {
    await _pump(tester, '/c/vida-nueva/admin');
    expect(find.text('Predicaciones'), findsOneWidget);
    expect(find.text('Hoy'), findsNothing);
    expect(find.text('Estudios'), findsNothing);
  });

  testWidgets('a new account is sent to the welcome question once', (tester) async {
    final router = await _pump(tester, '/', current: null, needsWelcome: true);
    expect(_path(router), '/welcome');
    router.go('/');
    await tester.pumpAndSettle();
    expect(_path(router), '/');
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(_path(router), '/profile');
  });

  testWidgets('Estudios opens the picker when the church lookup fails', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final router = createRouter(initialLocation: '/profile');
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [
        repositoryProvider.overrideWithValue(_FakeRepository()),
        userIdProvider.overrideWith((ref) => Stream.value('user-1')),
        myChurchesProvider.overrideWith((ref) async => const [Membership(church: _vida, role: ChurchRole.editor)]),
        isPlatformAdminProvider.overrideWith((ref) async => false),
        currentChurchProvider.overrideWith((ref) async => throw Exception('offline')),
        needsWelcomeProvider.overrideWith((ref) async => false),
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
    await tester.tap(find.text('Estudios'));
    await tester.pumpAndSettle();
    expect(_path(router), '/churches');
  });
}
