import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/app/app.dart';
import 'package:selah/src/app/design/adaptive_tab_bar.dart';
import 'package:selah/src/app/theme.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/current_church.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/data/repository.dart';
import 'package:selah/src/features/welcome/welcome_state.dart';
import 'package:selah/src/l10n/locale.dart';
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
  Future<List<SermonRow>> sermons(String churchId) async => const [];

  @override
  Future<ChurchRole?> roleIn(String churchId) async => ChurchRole.editor;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _day(int n) => {
      'day_number': n,
      'title': 'Día $n del camino',
      'bible_reading': 'Juan 15:$n',
      'main_idea': 'Idea principal $n',
      'reflection': 'Reflexión $n',
      'prayer': 'Oración $n',
      'questions': <String>[],
    };

Map<String, dynamic> _json() => {
      'id': 'study-1',
      'slug': 'seguir',
      'title': 'Seguir a Jesús',
      'number_of_days': 5,
      'bible_version_code': 'RVR1960',
      'output_language': 'es',
      'published_at': '2026-10-18T10:00:00Z',
      'summary': const <String, dynamic>{},
      'sermons': {'youtube_video_id': 'v'},
      'devotional_days': [for (var i = 1; i <= 5; i++) _day(i)],
      'study_translations': const <Map<String, dynamic>>[],
    };

Future<GoRouter> _pump(WidgetTester tester, String location) async {
  SharedPreferences.setMockInitialValues({});
  final router = createRouter(initialLocation: location);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(_FakeRepository()),
      savedLanguageProvider.overrideWithValue('es'),
      userIdProvider.overrideWith((ref) => Stream.value('user-1')),
      myChurchesProvider.overrideWith((ref) async => const [Membership(church: _vida, role: ChurchRole.editor)]),
      isPlatformAdminProvider.overrideWith((ref) async => false),
      currentChurchProvider.overrideWith((ref) async => _vida),
      needsWelcomeProvider.overrideWith((ref) async => false),
      newestStudyProvider.overrideWith((ref, churchId) async => PublicStudy.fromJson(_json())),
      studyProvider.overrideWith((ref, key) async => key.slug == 'seguir' ? PublicStudy.fromJson(_json()) : null),
      clockProvider.overrideWithValue(() => DateTime(2026, 10, 27, 9)),
    ],
    child: Consumer(
      builder: (context, ref, _) => MaterialApp.router(
        theme: selahLightTheme(),
        routerConfig: router,
        locale: ref.watch(appLocaleProvider),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return router;
}

/// The top page's address, including pages opened with push.
String _path(GoRouter router) => router.state.uri.path;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester, String tooltip) => _tap(tester, find.byTooltip(tooltip).first);

const _reader1 = '/c/vida-nueva/studies/seguir/day/1';

/// The iOS back swipe: a drag from the left edge to past the middle of the screen. Test pointer events carry no
/// real timing, so a short flick has no velocity and settles back; past halfway it pops, as on a device.
Future<void> _edgeSwipe(WidgetTester tester) async {
  final gesture = await tester.startGesture(const Offset(5, 300));
  await gesture.moveBy(const Offset(20, 0));
  await tester.pump();
  for (var i = 0; i < 10; i++) {
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Runs [body] as on an iPhone, then puts the test platform back.
Future<void> _onIos(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

/// The Hoy tab in the tab bar, apart from Hoy's own large title.
Finder _hoyTab() => find.descendant(of: find.byType(AdaptiveTabBar), matching: find.text('Hoy'));

void main() {
  test('every route builds a page, so none loses its transition or back gesture', () {
    final bare = <String>[];
    void walk(List<RouteBase> routes) {
      for (final route in routes) {
        if (route is GoRoute && route.pageBuilder == null) bare.add(route.path);
        walk(route.routes);
      }
    }

    final router = createRouter();
    addTearDown(router.dispose);
    walk(router.configuration.routes);
    expect(bare, isEmpty, reason: 'use _page(...) instead of a bare builder');
  });

  testWidgets('back from a reader opened on Hoy returns to Hoy', (tester) async {
    final router = await _pump(tester, '/');
    await _tap(tester, find.text('Reflexión'));
    expect(_path(router), _reader1);
    await _back(tester, 'Volver');
    expect(_path(router), '/');
    expect(find.text('SEGUIR A JESÚS · DÍA 1 DE 5'), findsOneWidget);
    expect(find.text('Idea principal 1'), findsOneWidget);
  });

  testWidgets('back from a reader opened on the study page returns to the study page', (tester) async {
    final router = await _pump(tester, '/c/vida-nueva/studies/seguir');
    await _tap(tester, find.text('Día 2 del camino'));
    expect(_path(router), '/c/vida-nueva/studies/seguir/day/2');
    await _back(tester, 'Volver');
    expect(_path(router), '/c/vida-nueva/studies/seguir');
  });

  testWidgets('next day replaces the reader so one back leaves it', (tester) async {
    final router = await _pump(tester, '/');
    await _tap(tester, find.text('Reflexión'));
    await tester.scrollUntilVisible(find.text('Día siguiente'), 300, scrollable: find.byType(Scrollable).first);
    await _tap(tester, find.text('Día siguiente'));
    expect(_path(router), endsWith('/day/2'));
    await _back(tester, 'Volver');
    expect(_path(router), '/');
  });

  testWidgets('a reader opened from a link goes back to its study page', (tester) async {
    final router = await _pump(tester, '/c/vida-nueva/studies/seguir/day/3');
    await _back(tester, 'Volver');
    expect(_path(router), '/c/vida-nueva/studies/seguir');
  });

  testWidgets('next day on a reader opened from a link still goes back to its study page', (tester) async {
    final router = await _pump(tester, '/c/vida-nueva/studies/seguir/day/3');
    await tester.scrollUntilVisible(find.text('Día siguiente'), 300, scrollable: find.byType(Scrollable).first);
    await _tap(tester, find.text('Día siguiente'));
    expect(_path(router), '/c/vida-nueva/studies/seguir/day/4');
    await _back(tester, 'Volver');
    expect(_path(router), '/c/vida-nueva/studies/seguir');
  });

  testWidgets('Estudios comes back to the church it showed', (tester) async {
    final router = await _pump(tester, '/');
    await _tap(tester, find.text('Estudios'));
    expect(_path(router), '/c/vida-nueva');
    await _tap(tester, find.text('Hoy'));
    expect(_path(router), '/');
    await _tap(tester, find.text('Estudios'));
    expect(_path(router), '/c/vida-nueva');
  });

  testWidgets('tapping Estudios while on it stays on the church', (tester) async {
    final router = await _pump(tester, '/c/vida-nueva');
    expect(find.text('Iglesia Vida Nueva'), findsWidgets);
    await _tap(tester, find.text('Estudios'));
    expect(_path(router), '/c/vida-nueva');
    expect(find.text('No encontramos esta iglesia.'), findsNothing);
    expect(find.text('Iglesia Vida Nueva'), findsWidgets);
  });

  testWidgets('a study page opened from a link goes back to its church', (tester) async {
    final router = await _pump(tester, '/c/vida-nueva/studies/seguir');
    await _back(tester, 'Volver');
    expect(_path(router), '/c/vida-nueva');
  });

  testWidgets('the reader and study page cover the tab bar', (tester) async {
    final router = await _pump(tester, '/');
    expect(_hoyTab().hitTestable(), findsOneWidget);
    await _tap(tester, find.text('Reflexión'));
    expect(_path(router), _reader1);
    expect(_hoyTab().hitTestable(), findsNothing);
    await _back(tester, 'Volver');
    router.push('/c/vida-nueva/studies/seguir');
    await tester.pumpAndSettle();
    expect(_hoyTab().hitTestable(), findsNothing);
  });

  testWidgets('a tab keeps its scroll position when you come back', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(tester, '/profile');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    final before = tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;
    expect(before, greaterThan(0));
    await _tap(tester, find.text('Hoy'));
    await _tap(tester, find.text('Perfil').last);
    expect(tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels, before);
  });

  testWidgets('changing language in the reader keeps the reader and its back stack', (tester) async {
    final router = await _pump(tester, '/');
    await _tap(tester, find.text('Reflexión'));
    expect(_path(router), _reader1);
    await _tap(tester, find.byTooltip('Idioma'));
    await _tap(tester, find.text('English').last);
    expect(_path(router), _reader1);
    await _back(tester, 'Back');
    expect(_path(router), '/');
  });

  testWidgets('iOS edge swipe from a reader opened on Hoy returns to Hoy', (tester) async {
    await _onIos(() async {
      final router = await _pump(tester, '/');
      await _tap(tester, find.text('Reflexión'));
      expect(_path(router), _reader1);
      await _edgeSwipe(tester);
      expect(_path(router), '/');
      expect(find.text('Idea principal 1'), findsOneWidget);
    });
  });

  testWidgets('iOS edge swipe from a reader opened on the study page returns to the study page', (tester) async {
    await _onIos(() async {
      final router = await _pump(tester, '/c/vida-nueva/studies/seguir');
      await _tap(tester, find.text('Día 2 del camino'));
      expect(_path(router), '/c/vida-nueva/studies/seguir/day/2');
      await _edgeSwipe(tester);
      expect(_path(router), '/c/vida-nueva/studies/seguir');
    });
  });
}
