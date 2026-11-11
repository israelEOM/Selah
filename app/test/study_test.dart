import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:selah/src/app/design/art.dart';
import 'package:selah/src/app/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/core/format.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/progress.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/features/study/reader_page.dart';
import 'package:selah/src/features/study/study_page.dart';
import 'package:selah/src/features/study/tick_dock.dart';
import 'package:selah/src/features/today/part_tick.dart';
import 'package:selah/src/features/today/today_selection.dart';
import 'package:selah/src/features/today/week_rings.dart';
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

const _phone = Size(390, 844);

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

Future<GoRouter> _pump(
  WidgetTester tester,
  String location, {
  Map<String, Object> prefs = const {},
  double textScale = 1,
  Size? size,
  TargetPlatform? platform,
  Map<String, dynamic>? json,
  bool reduceMotion = false,
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  SharedPreferences.setMockInitialValues(prefs);
  final router = GoRouter(initialLocation: location, routes: [
    GoRoute(path: '/', builder: (_, _) => const Text('HOME')),
    GoRoute(path: '/today', builder: (_, _) => const Text('TODAY')),
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
          key == (churchId: 'A', slug: 'retiro-espiritual') ? PublicStudy.fromJson(json ?? _json) : null),
    ],
    child: MaterialApp.router(
      theme: selahLightTheme().copyWith(platform: platform),
      routerConfig: router,
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: reduceMotion),
        child: child!,
      ),
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
    await tester.scrollUntilVisible(find.text('Día 2 · Título día 2'), 300);
    await tester.tap(find.text('Día 2 · Título día 2'));
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

  testWidgets('the reader shows a 120-tall illustration for the day under its header', (tester) async {
    await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual/day/2');
    final art = find.byType(SelahArt);
    expect(art, findsOneWidget);
    expect(tester.getSize(art).height, 120);
    expect(find.byType(ArtPlaceholder), findsOneWidget);
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

  testWidgets('ticking from the bar marks the part on the study page', (tester) async {
    final router = await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual/day/1', size: _phone);
    expect(find.text('Marcar como leído'), findsNothing);
    for (final part in ['reading', 'reflection', 'prayer']) {
      await tester.tap(find.byKey(ValueKey('dock-$part')));
      await tester.pumpAndSettle();
    }
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('progress:study-1'), contains('"doneOn"'));
    router.go('/c/vida-nueva/studies/retiro-espiritual');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Día 2 · Título día 2'), 300);
    expect(tester.widgetList<PartRing>(find.byType(PartRing)).where((r) => r.complete), hasLength(1));
    expect(find.text('Día 1 · Título día 1'), findsOneWidget);
  });

  testWidgets('the tick bar stays on screen while scrolling to the prayer', (tester) async {
    await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual/day/1', size: _phone);
    expect(find.byType(PartTick), findsNothing);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.byType(TickDock).hitTestable(), findsOneWidget);
    expect(find.text('Toca para marcar'), findsOneWidget);
  });

  testWidgets('the current part follows the section in view', (tester) async {
    await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual/day/1', size: _phone);
    Finder inChip(String part, String text) =>
        find.descendant(of: find.byKey(ValueKey('dock-$part')), matching: find.text(text));
    expect(inChip('reading', 'Lectura'), findsOneWidget);
    expect(inChip('prayer', 'Oración'), findsNothing);
    // The reflection's heading passes 45% of the screen while the page still has more below.
    final heading = tester.getTopLeft(find.text('REFLEXIÓN')).dy;
    // In two drags, as a finger scrolls: the section positions the bar reads lag the scroll by a frame.
    final distance = heading - 844 * 0.3;
    await tester.drag(find.byType(Scrollable).first, Offset(0, -distance / 2));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, Offset(0, -distance / 2));
    await tester.pumpAndSettle();
    expect(inChip('reflection', 'Reflexión'), findsOneWidget);
    expect(inChip('reading', 'Lectura'), findsNothing);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(inChip('prayer', 'Oración'), findsOneWidget);
    expect(inChip('reading', 'Lectura'), findsNothing);
  });

  testWidgets('a day without prayer shows only two chips and completes after two ticks', (tester) async {
    final json = {
      ..._json,
      'devotional_days': [
        {..._day(1), 'prayer': null},
        _day(2),
        _day(3),
      ],
    };
    await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual/day/1', size: _phone, json: json);
    expect(find.byKey(const ValueKey('dock-prayer')), findsNothing);
    expect(find.byKey(const ValueKey('dock-reading')), findsOneWidget);
    expect(find.byKey(const ValueKey('dock-reflection')), findsOneWidget);
    for (final part in ['reading', 'reflection']) {
      await tester.tap(find.byKey(ValueKey('dock-$part')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Día completo · volver a Hoy'), findsOneWidget);
  });

  testWidgets('completing the day shows the back to Today pill and does not navigate on its own', (tester) async {
    final router = await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual/day/1', size: _phone);
    final container = ProviderScope.containerOf(tester.element(find.byType(ReaderPage)));
    for (final part in ['reading', 'reflection', 'prayer']) {
      await tester.tap(find.byKey(ValueKey('dock-$part')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Día completo · volver a Hoy'), findsOneWidget);
    expect(find.text('Toca para marcar'), findsNothing);
    expect(router.state.uri.path, '/c/vida-nueva/studies/retiro-espiritual/day/1');
    // Moment A waits for the pill, so it plays on Today rather than behind the reader.
    expect(container.read(justFinishedProvider), isNull);
    await tester.tap(find.text('Día completo · volver a Hoy'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/today');
    expect(container.read(justFinishedProvider), (studyId: 'study-1', day: 1));
  });

  testWidgets('re-opening a finished day shows the pill but does not replay moment A', (tester) async {
    final router = await _pump(
      tester,
      '/c/vida-nueva/studies/retiro-espiritual/day/1',
      size: _phone,
      prefs: {'progress:study-1': '{"1":{"parts":["reading","reflection","prayer"],"doneOn":"2026-10-27"}}'},
    );
    final container = ProviderScope.containerOf(tester.element(find.byType(ReaderPage)));
    expect(find.text('Día completo · volver a Hoy'), findsOneWidget);
    expect(
      tester.getSemantics(find.descendant(of: find.byKey(const ValueKey('dock-complete')), matching: find.byType(Pressable))),
      isSemantics(label: 'Día completo · volver a Hoy', isButton: true),
    );
    await tester.tap(find.text('Día completo · volver a Hoy'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/today');
    expect(container.read(justFinishedProvider), isNull);
  });

  testWidgets('a quick second tap on a chip is ignored', (tester) async {
    await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual/day/1', size: _phone);
    await tester.tap(find.byKey(const ValueKey('dock-reading')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const ValueKey('dock-reading')));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('progress:study-1'), contains('reading'));
  });

  testWidgets('a tick from the bar lands on the date picked on Today', (tester) async {
    await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual/day/1', size: _phone);
    final container = ProviderScope.containerOf(tester.element(find.byType(ReaderPage)));
    container.read(selectedDateProvider.notifier).select('2020-01-02');
    await tester.tap(find.byKey(const ValueKey('dock-reading')));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('progress:study-1'), contains('2020-01-02'));
  });

  testWidgets('each chip in the bar is a checkable button named for its part', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual/day/1', size: _phone);
    await tester.tap(find.byKey(const ValueKey('dock-reflection')));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.byKey(const ValueKey('dock-reflection'))),
      matchesSemantics(
        label: 'Reflexión',
        isButton: true,
        hasCheckedState: true,
        isChecked: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    // The wide chip says what a tap does.
    expect(tester.getSemantics(find.byKey(const ValueKey('dock-reading'))).hint, 'Toca para marcar');
    expect(tester.getSemantics(find.byKey(const ValueKey('dock-prayer'))).hint, isEmpty);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('dock-prayer'))),
      matchesSemantics(
        label: 'Oración',
        isButton: true,
        hasCheckedState: true,
        isChecked: false,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('the day complete pill slides in, or only fades with Reduce Motion', (tester) async {
    for (final reduce in [false, true]) {
      await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual/day/1', size: _phone, reduceMotion: reduce);
      for (final part in ['reading', 'reflection', 'prayer']) {
        await tester.tap(find.byKey(ValueKey('dock-$part')));
        await tester.pumpAndSettle();
      }
      expect(find.text('Día completo · volver a Hoy'), findsOneWidget);
      final slides = find.descendant(of: find.byType(TickDock), matching: find.byType(SlideTransition));
      expect(slides, reduce ? findsNothing : findsOneWidget, reason: 'reduce motion: $reduce');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('a rebuild with the same current part does not restart the widening', (tester) async {
    var current = DayPart.reading;
    late StateSetter rebuild;
    await tester.pumpWidget(MaterialApp(
      theme: selahLightTheme(),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 366,
            child: StatefulBuilder(builder: (context, setState) {
              rebuild = setState;
              return TickDock(
                parts: DayPart.values,
                ticked: const {},
                current: current,
                onTick: (_) {},
                onComplete: () {},
              );
            }),
          ),
        ),
      ),
    ));
    rebuild(() => current = DayPart.prayer);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    rebuild(() {});
    await tester.pump();
    // Past the 280 ms the widening takes from the first change: a restart would still be animating.
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('the tick bar fits at 200% text', (tester) async {
    await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual/day/1', size: _phone, textScale: 2);
    expect(find.byType(TickDock), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final part in ['reading', 'reflection', 'prayer']) {
      await tester.tap(find.byKey(ValueKey('dock-$part')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Día completo · volver a Hoy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the desktop reader keeps inline ticks and no dock', (tester) async {
    await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual/day/1', size: const Size(1280, 900), platform: TargetPlatform.android);
    expect(find.byType(TickDock), findsNothing);
    expect(find.byType(PartTick), findsNWidgets(3));
    for (final part in ['reading', 'reflection', 'prayer']) {
      await tester.ensureVisible(find.byKey(ValueKey('tick-$part')));
      await tester.tap(find.byKey(ValueKey('tick-$part')));
      await tester.pumpAndSettle();
    }
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('progress:study-1'), contains('"doneOn"'));
  });

  testWidgets('old read marks still show as done', (tester) async {
    await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual', prefs: {'read:study-1': ['2']});
    await tester.scrollUntilVisible(find.text('Día 2 · Título día 2'), 300);
    final done = tester.widgetList<PartRing>(find.byType(PartRing)).where((r) => r.complete).toList();
    expect(done, hasLength(1));
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
    await tester.scrollUntilVisible(find.text('Día 2 · Título día 2'), 300);
    await tester.tap(find.text('Día 2 · Título día 2'));
    await tester.pumpAndSettle();
    expect(extra, isA<PublicStudy>());
  });

  testWidgets('the reader fits at 200% text size', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual/day/2', textScale: 2);
    expect(find.text('Título día 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  const desktop = Size(1280, 900);

  testWidgets('the study page puts the days beside the summary on desktop', (tester) async {
    await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual', size: desktop, platform: TargetPlatform.android);
    expect(tester.getTopLeft(find.text('Día 1 · Título día 1')).dx, greaterThan(tester.getTopRight(find.text('La necesidad del retiro espiritual')).dx));
  });

  testWidgets("the reader lists the study's days beside the text on desktop", (tester) async {
    await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual/day/2', size: desktop, platform: TargetPlatform.android);
    for (final n in [1, 2, 3]) {
      expect(find.textContaining('Título día $n'), findsWidgets);
    }
    expect(tester.getSize(find.text('Reflexión 2')).width, lessThanOrEqualTo(680));
  });

  testWidgets("tapping a day in the reader's side column opens it", (tester) async {
    await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual/day/2', size: desktop, platform: TargetPlatform.android);
    await tester.tap(find.textContaining('Título día 3'));
    await tester.pumpAndSettle();
    expect(find.text('Reflexión 3'), findsOneWidget);
  });

  testWidgets('the reader on a phone has no side column', (tester) async {
    await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual/day/2', size: const Size(390, 844), platform: TargetPlatform.android);
    expect(find.textContaining('Título día 1'), findsNothing);
    expect(find.textContaining('Título día 3'), findsNothing);
  });

  testWidgets('the study page header art carries the study hero tag', (tester) async {
    await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual', size: _phone, platform: TargetPlatform.android);
    final art = find.byWidgetPredicate((w) => w is SelahArt && w.heroTag == studyArtTag('study-1'));
    expect(art, findsOneWidget);
    expect(tester.getSize(art).height, 150);
  });

  testWidgets('the study header art collapses as the page scrolls', (tester) async {
    await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual', size: _phone, platform: TargetPlatform.android);
    final art = find.byWidgetPredicate((w) => w is SelahArt && w.heroTag == studyArtTag('study-1'));
    // The bar's own height scrolls first, then the art shrinks under it.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(tester.getSize(art).height, lessThan(150));
  });

  testWidgets('the devotional path shows a ring per day', (tester) async {
    await _pump(tester, '/c/vida-nueva/studies/retiro-espiritual',
        size: _phone,
        platform: TargetPlatform.android,
        prefs: {'progress:study-1': '{"2":{"parts":["reading"],"doneOn":null}}'});
    await tester.scrollUntilVisible(find.text('Día 3 · Título día 3'), 300);
    final rings = tester.widgetList<PartRing>(find.byType(PartRing)).toList();
    expect(rings, hasLength(3));
    expect(rings[1].parts, {DayPart.reading});
    expect(rings[0].parts, isEmpty);
    expect(find.text('Día 2 · Título día 2'), findsOneWidget);
  });
}
