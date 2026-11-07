import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/app/app.dart';
import 'package:selah/src/app/theme.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/current_church.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/data/repository.dart';
import 'package:selah/src/features/home/language_menu.dart';
import 'package:selah/src/features/welcome/welcome_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _vida = Church(id: 'A', slug: 'vida-nueva', name: 'Iglesia Vida Nueva');

class _FakeRepository implements SelahRepository {
  @override
  Future<Church?> churchBySlug(String slug) async => slug == 'vida-nueva' ? _vida : null;

  @override
  Future<List<StudyCard>> publishedStudies(String churchId) async => const [];

  @override
  Future<List<Church>> publicChurches() async => const [_vida];

  @override
  Future<ChurchRole?> roleIn(String churchId) async => null;

  @override
  Future<List<ChurchEvent>> upcomingEvents(String churchId) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<GoRouter> _pumpRouter(WidgetTester tester, String location, {Size size = const Size(1280, 800)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final router = createRouter(initialLocation: location);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(_FakeRepository()),
      userIdProvider.overrideWith((ref) => Stream.value(null)),
      myChurchesProvider.overrideWith((ref) async => const []),
      isPlatformAdminProvider.overrideWith((ref) async => false),
      currentChurchProvider.overrideWith((ref) async => _vida),
      needsWelcomeProvider.overrideWith((ref) async => false),
    ],
    child: MaterialApp.router(
      theme: selahLightTheme().copyWith(platform: TargetPlatform.android),
      routerConfig: router,
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await tester.pumpAndSettle();
  return router;
}

String _path(GoRouter router) => router.routerDelegate.currentConfiguration.uri.path;

Finder _inHeader(String label) => find.descendant(of: find.byKey(SiteHeader.headerKey), matching: find.text(label));

void main() {
  testWidgets('tapping Estudios in the header opens the church', (tester) async {
    final router = await _pumpRouter(tester, '/');
    await tester.tap(_inHeader('Estudios'));
    await tester.pumpAndSettle();
    expect(_path(router), '/c/vida-nueva');
  });

  testWidgets('the selected link follows the route', (tester) async {
    await _pumpRouter(tester, '/profile');
    final perfil = tester.widget<Text>(_inHeader('Perfil'));
    final style = DefaultTextStyle.of(tester.element(_inHeader('Perfil'))).style.merge(perfil.style);
    expect(style.color, selahLightTheme().colorScheme.primary);
  });

  testWidgets('header links are focusable and activate with Enter', (tester) async {
    final router = await _pumpRouter(tester, '/');
    final estudios = find.ancestor(of: _inHeader('Estudios'), matching: find.byType(TextButton));
    for (var i = 0; i < 12 && !Focus.of(tester.element(_inHeader('Estudios'))).hasFocus; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(Focus.of(tester.element(_inHeader('Estudios'))).hasFocus, isTrue);
    expect(estudios, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_path(router), '/c/vida-nueva');
  });

  testWidgets('crossing 1024 px keeps the tab stack', (tester) async {
    final router = await _pumpRouter(tester, '/c/vida-nueva/events');
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(_path(router), '/c/vida-nueva/events');
    expect(find.byKey(SiteHeader.headerKey), findsNothing);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations[bar.selectedIndex], isA<NavigationDestination>().having((d) => d.label, 'label', 'Eventos'));
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpAndSettle();
    final eventos = tester.widget<Text>(_inHeader('Eventos'));
    final style = DefaultTextStyle.of(tester.element(_inHeader('Eventos'))).style.merge(eventos.style);
    expect(style.color, selahLightTheme().colorScheme.primary);
  });

  testWidgets('a reader opened from a link shows the header with Estudos selected', (tester) async {
    await _pumpRouter(tester, '/c/vida-nueva/studies/retiro/day/1');
    expect(find.byKey(SiteHeader.headerKey), findsOneWidget);
    final estudios = tester.widget<Text>(_inHeader('Estudios'));
    final style = DefaultTextStyle.of(tester.element(_inHeader('Estudios'))).style.merge(estudios.style);
    expect(style.color, selahLightTheme().colorScheme.primary);
  });

  testWidgets('the header on the study page goes to Hoje', (tester) async {
    final router = await _pumpRouter(tester, '/c/vida-nueva/studies/retiro');
    await tester.tap(_inHeader('Hoy'));
    await tester.pumpAndSettle();
    expect(_path(router), '/');
  });

  testWidgets('the study page on a phone has no header', (tester) async {
    await _pumpRouter(tester, '/c/vida-nueva/studies/retiro', size: const Size(390, 844));
    expect(find.byKey(SiteHeader.headerKey), findsNothing);
  });

  testWidgets('the study page on desktop has one language menu, in the header', (tester) async {
    await _pumpRouter(tester, '/c/vida-nueva/studies/retiro');
    final shown = find.descendant(of: find.byType(LanguageMenu), matching: find.byType(PopupMenuButton<String>));
    expect(shown, findsOneWidget);
    expect(find.descendant(of: find.byKey(SiteHeader.headerKey), matching: shown), findsOneWidget);
  });
}
