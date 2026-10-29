import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:selah/src/app/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/core/format.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/features/study/reader_page.dart';
import 'package:selah/src/features/study/study_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _day(int n) => {
      'day_number': n,
      'title': 'Título día $n',
      'bible_reading': 'Salmos 27:$n',
      'main_idea': 'Idea $n',
      'reflection': 'Reflexión $n',
      'application': 'Aplicación $n',
      'questions': ['¿Pregunta $n?'],
      'prayer': 'Oración $n',
      'start_seconds': 100.0 * n,
      'end_seconds': 100.0 * n + 50,
    };

const _church = Church(id: 'A', slug: 'vida-nueva', name: 'Iglesia Vida Nueva');

final _json = {
  'id': 'study-1',
  'slug': 'retiro-espiritual',
  'title': 'La necesidad del retiro espiritual',
  'central_message': 'Mensaje central',
  'number_of_days': 3,
  'bible_version_code': 'RVR1960',
  'published_at': '2026-10-18T10:00:00Z',
  'summary': {
    'introduction': 'Introducción',
    'main_passage': '2 Reyes 2:25',
    'points': [
      {'title': 'Punto uno', 'summary': 'Resumen uno', 'subpoints': ['Sub'], 'references': ['Mateo 4:1'], 'start_seconds': 2183.0},
    ],
    'key_takeaways': ['Para recordar uno'],
  },
  'sermons': {
    'youtube_video_id': 'Bflib6PHb68',
    'title': 'Eliseo continúa su ministerio',
    'preacher': 'Ángel Álvarez',
    'channel': 'Iglesia',
    'thumbnail_url': null,
    'sermon_date': null,
  },
  // Out of order on purpose: the reader must not depend on the database order.
  'devotional_days': [_day(3), _day(1), _day(2)],
};

Future<GoRouter> _pump(WidgetTester tester, String location, {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final router = GoRouter(initialLocation: location, routes: [
    GoRoute(path: '/', builder: (_, _) => const Text('HOME')),
    GoRoute(path: '/c/vida-nueva', builder: (_, _) => const Text('CHURCH')),
    GoRoute(path: '/c/vida-nueva/studies/:slug', builder: (_, s) => StudyPage(church: _church, slug: s.pathParameters['slug']!)),
    GoRoute(
      path: '/c/vida-nueva/studies/:slug/day/:number',
      builder: (_, s) => ReaderPage(
        church: _church,
        slug: s.pathParameters['slug']!,
        dayNumber: int.parse(s.pathParameters['number']!),
      ),
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      studyProvider.overrideWith((ref, key) async =>
          key == (churchId: 'A', slug: 'retiro-espiritual') ? PublicStudy.fromJson(_json) : null),
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

void main() {
  test('study days are sorted by day number', () {
    final study = PublicStudy.fromJson(_json);
    expect(study.days.map((d) => d.number), [1, 2, 3]);
    expect(study.sermon.preacher, 'Ángel Álvarez');
    expect(study.days.first.questions, ['¿Pregunta 1?']);
  });

  test('Bible reader link opens the passage in YouVersion', () {
    expect(bibleReaderUrl('2 Reyes 2:25', 'RVR1960').toString(), 'https://www.bible.com/bible/149/2KI.2.25.RVR1960');
    expect(bibleReaderUrl('Colosenses 3:1-4', 'NVI').toString(), 'https://www.bible.com/bible/128/COL.3.1-4.NVI');
    expect(bibleReaderUrl('Cânticos 2', 'NVI-PT').toString(), 'https://www.bible.com/bible/129/SNG.2.NVI');
    expect(bibleReaderUrl('1 John 4:7–8', 'ESV').toString(), 'https://www.bible.com/bible/59/1JN.4.7-8.ESV');
  });

  test('Bible reader link falls back to Bible Gateway when it cannot match', () {
    for (final (reference, version) in [('Hechos 2:1', 'LBLA'), ('Sermón del monte', 'RVR1960')]) {
      final uri = bibleReaderUrl(reference, version);
      expect(uri.host, 'www.biblegateway.com');
      expect(uri.queryParameters, {'search': reference, 'version': version});
    }
  });

  testWidgets('study page lists the days and opens one', (tester) async {
    final router = await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual');
    expect(find.text('La necesidad del retiro espiritual'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Título día 2'), 300);
    await tester.tap(find.text('Título día 2'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/c/vida-nueva/studies/retiro-espiritual/day/2');
  });

  testWidgets('unknown study says it is not available', (tester) async {
    await _pump(tester, '/c/vida-nueva/studies/no-existe');
    expect(find.text('Este estudio no está disponible.'), findsOneWidget);
  });

  testWidgets('reader shows the day and its position', (tester) async {
    await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual/day/2');
    expect(find.text('DÍA 2 DE 3'), findsOneWidget);
    expect(find.text('Título día 2'), findsOneWidget);
    expect(find.text('Reflexión 2'), findsOneWidget);
  });

  testWidgets('the reader shows the day on iOS', (tester) async {
    // Portrait: the iOS sliver bar only builds its large title there.
    tester.view.physicalSize = const Size(1800, 2700);
    addTearDown(tester.view.resetPhysicalSize);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual/day/2');
      expect(tester.takeException(), isNull);
      expect(find.text('Título día 2'), findsOneWidget);
      expect(find.byTooltip('Volver'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('reader moves to the next day', (tester) async {
    final router = await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual/day/2');
    await tester.scrollUntilVisible(find.text('Día siguiente'), 300);
    await tester.ensureVisible(find.text('Día siguiente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Día siguiente'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/c/vida-nueva/studies/retiro-espiritual/day/3');
  });

  testWidgets('last day has no next day', (tester) async {
    await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual/day/3');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Día anterior').hitTestable(), findsOneWidget);
    expect(find.text('Día siguiente'), findsNothing);
  });

  testWidgets('ticking the three parts in the reader marks the day done on the study page', (tester) async {
    final router = await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual/day/1');
    expect(find.text('Marcar como leído'), findsNothing);
    for (final part in ['reading', 'reflection', 'prayer']) {
      await tester.ensureVisible(find.byKey(ValueKey('tick-$part')));
      await tester.tap(find.byKey(ValueKey('tick-$part')));
      await tester.pumpAndSettle();
    }
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('progress:study-1'), contains('"doneOn"'));
    router.go('/c/vida-nueva/studies/retiro-espiritual');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Título día 2'), 300);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('Título día 1'), findsOneWidget);
  });

  testWidgets('old read marks still show as done', (tester) async {
    await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual', prefs: {'read:study-1': ['2']});
    await tester.scrollUntilVisible(find.text('Título día 2'), 300);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('the reader header carries the same hero tag as Hoy', (tester) async {
    await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual/day/1');
    final hero = find.byWidgetPredicate((w) => w is Hero && w.tag == dayHeroTag('study-1', 1));
    expect(hero, findsOneWidget);
    expect(find.descendant(of: hero, matching: find.text('Título día 1')), findsOneWidget);
    expect(find.descendant(of: hero, matching: find.text('Idea 1')), findsOneWidget);
    expect(find.descendant(of: hero, matching: find.byType(HeroCard)), findsOneWidget);
  });

  testWidgets('the main idea appears once in the reader', (tester) async {
    await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual/day/1');
    expect(find.text('Idea 1'), findsOneWidget);
  });

  testWidgets('the reader shows skeletons while the study loads', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [studyProvider.overrideWith((ref, key) => Completer<PublicStudy?>().future)],
      child: MaterialApp(
        theme: selahLightTheme(),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ReaderPage(church: _church, slug: 'retiro-espiritual', dayNumber: 1),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(Skeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('study page shows skeletons while it loads', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [studyProvider.overrideWith((ref, key) => Completer<PublicStudy?>().future)],
      child: MaterialApp(
        theme: selahLightTheme(),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const StudyPage(church: _church, slug: 'retiro-espiritual'),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(Skeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('the study page builds on iOS in portrait', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual');
      expect(tester.takeException(), isNull);
      expect(find.text('La necesidad del retiro espiritual'), findsOneWidget);
      expect(find.byTooltip('Volver'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a day opens in the reader with the loaded study', (tester) async {
    Object? extra;
    SharedPreferences.setMockInitialValues({});
    final router = GoRouter(initialLocation: '/c/vida-nueva/studies/retiro-espiritual', routes: [
      GoRoute(path: '/c/vida-nueva', builder: (_, _) => const Text('CHURCH')),
      GoRoute(
        path: '/c/vida-nueva/studies/:slug',
        builder: (_, s) => StudyPage(church: _church, slug: s.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/c/vida-nueva/studies/:slug/day/:number',
        builder: (_, s) {
          extra = s.extra;
          return const Text('READER');
        },
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [studyProvider.overrideWith((ref, key) async => PublicStudy.fromJson(_json))],
      child: MaterialApp.router(
        theme: selahLightTheme(),
        routerConfig: router,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Título día 2'), 300);
    await tester.tap(find.text('Título día 2'));
    await tester.pumpAndSettle();
    expect(extra, isA<PublicStudy>());
  });
}
