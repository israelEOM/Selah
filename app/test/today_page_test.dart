import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/app/design/art.dart';
import 'package:selah/src/app/theme.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/current_church.dart';
import 'package:selah/src/data/progress.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/features/study/reader_page.dart';
import 'package:selah/src/features/today/finish_moment.dart';
import 'package:selah/src/features/today/today_page.dart';
import 'package:selah/src/features/today/today_refresh.dart';
import 'package:selah/src/features/today/today_selection.dart';
import 'package:selah/src/l10n/locale.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _church = Church(id: 'A', slug: 'vida-nueva', name: 'Iglesia Vida Nueva');

/// Tuesday.
final _now = DateTime(2026, 10, 27, 9);

Map<String, dynamic> _day(int n, {bool prayer = true, String lang = 'es'}) => {
      'day_number': n,
      'title': lang == 'es' ? 'Día $n del camino' : 'Dia $n em português',
      'bible_reading': 'Juan 15:$n',
      'main_idea': 'Idea principal $n',
      'reflection': 'Reflexión $n',
      if (prayer) 'prayer': 'Oración $n',
      'questions': <String>[],
    };

Map<String, dynamic> _json({List<Map<String, dynamic>>? days, Map<String, dynamic> summary = const {}}) => {
      'id': 'study-1',
      'slug': 'seguir',
      'title': 'Seguir a Jesús',
      'number_of_days': 5,
      'bible_version_code': 'RVR1960',
      'output_language': 'es',
      'published_at': '2026-10-18T10:00:00Z',
      'summary': summary,
      'sermons': {'youtube_video_id': 'v'},
      'devotional_days': days ?? [for (var i = 1; i <= 5; i++) _day(i)],
      'study_translations': [
        {
          'language': 'pt',
          'title': 'Seguir Jesus',
          'summary': const <String, dynamic>{},
          'days': [for (var i = 1; i <= 5; i++) _day(i, lang: 'pt')],
          'bible_version_code': 'NVI',
        },
      ],
    };

Future<void> _pump(
  WidgetTester tester, {
  Map<String, dynamic>? study,
  bool noStudy = false,
  Map<String, Object> prefs = const {},
  String language = 'es',
  DateTime Function()? clock,
  Future<PublicStudy?> Function()? newest,
  bool settle = true,
  double textScale = 1,
  Widget Function(GoRouterState)? reader,
  List<Override> overrides = const [],
  Size? size,
  TargetPlatform? platform,
  bool reduceMotion = false,
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  SharedPreferences.setMockInitialValues(prefs);
  final router = GoRouter(initialLocation: '/', routes: [
    GoRoute(path: '/', builder: (_, _) => const TodayPage()),
    GoRoute(path: '/c/vida-nueva', builder: (_, _) => const Text('STUDIES')),
    GoRoute(path: '/c/vida-nueva/studies/:slug', builder: (_, s) => Text('STUDY ${s.pathParameters['slug']}')),
    GoRoute(
      path: '/c/vida-nueva/studies/:slug/day/:n',
      builder: (_, s) => reader?.call(s) ?? Text('READER ${s.pathParameters['slug']} ${s.pathParameters['n']}'),
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      savedLanguageProvider.overrideWithValue(language),
      currentChurchProvider.overrideWith((ref) async => _church),
      newestStudyProvider.overrideWith(
          (ref, churchId) async => newest != null ? newest() : noStudy ? null : PublicStudy.fromJson(study ?? _json())),
      clockProvider.overrideWithValue(clock ?? () => _now),
      ...overrides,
    ],
    child: Consumer(
      builder: (context, ref, _) => MaterialApp.router(
        theme: selahLightTheme().copyWith(platform: platform),
        routerConfig: router,
        locale: ref.watch(appLocaleProvider),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: reduceMotion),
          child: child!,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  ));
  if (settle) await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _weekChecks() => find.descendant(of: find.byKey(const ValueKey('week')), matching: find.byIcon(Icons.check));

void main() {
  testWidgets('the empty studies page shows its scene', (tester) async {
    await _pump(tester, noStudy: true);
    expect(find.byWidgetPredicate((w) => w is SelahArt && w.artKey == 'scene-empty-studies'), findsOneWidget);
  });

  testWidgets('shows day 1 of a fresh study', (tester) async {
    await _pump(tester);
    expect(find.text('Iglesia Vida Nueva'), findsOneWidget);
    expect(find.text('SEGUIR A JESÚS · DÍA 1 DE 5'), findsOneWidget);
    expect(find.text('Día 1 del camino'), findsOneWidget);
    expect(find.text('Idea principal 1'), findsOneWidget);
    expect(find.text('Lectura bíblica'), findsOneWidget);
    expect(find.text('Reflexión'), findsOneWidget);
    expect(find.text('Oración'), findsOneWidget);
    expect(find.text('MARTES, 27 DE OCTUBRE'), findsOneWidget);
    expect(_weekChecks(), findsNothing);
    expect(find.byType(FinishLine), findsNothing);
  });

  testWidgets("Today's hero card shows the day's art", (tester) async {
    final json = _json();
    (json['devotional_days'] as List<Map<String, dynamic>>)[0]['art_key'] = 'vine-grapes';
    await _pump(tester, study: json);
    final art = find.descendant(of: find.byType(HeroCard), matching: find.byType(SelahArt));
    expect(art, findsOneWidget);
    expect(tester.widget<SelahArt>(art).artKey, 'vine-grapes');
    expect(tester.widget<SelahArt>(art).shape, ArtShape.circle);
  });

  testWidgets('a day without prayer has no prayer row', (tester) async {
    await _pump(tester, study: _json(days: [for (var i = 1; i <= 5; i++) _day(i, prayer: false)]));
    expect(find.text('Reflexión'), findsOneWidget);
    expect(find.text('Oración'), findsNothing);
  });

  testWidgets('ticking all parts shows the finish line and Leer el siguiente', (tester) async {
    await _pump(tester);
    for (final part in ['reading', 'reflection', 'prayer']) {
      await _tap(tester, find.byKey(ValueKey('tick-$part')));
    }
    expect(find.text('Listo por hoy.'), findsOneWidget);
    expect(find.text('Ve en paz.'), findsOneWidget);
    expect(find.text('Leer el siguiente'), findsOneWidget);
    expect(find.text('Idea principal 1'), findsOneWidget);
    expect(_weekChecks(), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('week-1')), matching: find.byIcon(Icons.check)), findsOneWidget);
  });

  testWidgets('Leer el siguiente opens day 2 in the reader', (tester) async {
    await _pump(tester, prefs: {
      'progress:study-1': '{"1":{"parts":["reading","reflection","prayer"],"doneOn":"2026-10-27"}}',
    });
    await _tap(tester, find.text('Leer el siguiente'));
    expect(find.text('READER seguir 2'), findsOneWidget);
  });

  testWidgets('tapping a row opens the day in the reader', (tester) async {
    await _pump(tester);
    await _tap(tester, find.text('Reflexión'));
    expect(find.text('READER seguir 1'), findsOneWidget);
  });

  testWidgets('the summary button opens the study page', (tester) async {
    await _pump(tester);
    await _tap(tester, find.text('Resumen del sermón'));
    expect(find.text('STUDY seguir'), findsOneWidget);
  });

  testWidgets('all done shows the main passage and a takeaway', (tester) async {
    await _pump(
      tester,
      study: _json(summary: {
        'main_passage': 'Juan 15:1-8',
        'key_takeaways': ['Permanecer en Él da fruto'],
      }),
      prefs: {
        'read:study-1': ['1', '2', '3', '4', '5'],
      },
    );
    expect(find.text('Para meditar hoy'), findsOneWidget);
    expect(find.text('PASAJE PRINCIPAL · JUAN 15:1-8'), findsOneWidget);
    expect(tester.widget<SettleWords>(find.byType(SettleWords)).text, 'Permanecer en Él da fruto');
    expect(find.text('Leer Juan 15:1-8'), findsOneWidget);
    expect(find.text('Resumen del sermón'), findsOneWidget);
  });

  testWidgets('no study shows the empty message', (tester) async {
    await _pump(tester, noStudy: true);
    expect(find.text('Tu iglesia aún no ha publicado estudios.'), findsOneWidget);
    await _tap(tester, find.text('Ver estudios'));
    expect(find.text('STUDIES'), findsOneWidget);
  });

  testWidgets('shows the study in the chosen language', (tester) async {
    await _pump(tester, language: 'pt');
    expect(find.text('SEGUIR JESUS · DIA 1 DE 5'), findsOneWidget);
    expect(find.text('Dia 1 em português'), findsOneWidget);
    expect(find.text('Leitura bíblica'), findsOneWidget);
  });

  group('the next day', () {
    const doneDay1 = {'progress:study-1': '{"1":{"parts":["reading","reflection","prayer"],"doneOn":"2026-10-27"}}'};

    testWidgets('shows after the app comes back the next morning', (tester) async {
      var now = DateTime(2026, 10, 27, 23, 59);
      await _pump(tester, prefs: doneDay1, clock: () => now);
      expect(find.text('Listo por hoy.'), findsOneWidget);
      now = DateTime(2026, 10, 28, 7);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Listo por hoy.'), findsNothing);
      expect(find.text('SEGUIR A JESÚS · DÍA 2 DE 5'), findsOneWidget);
      expect(find.text('MIÉRCOLES, 28 DE OCTUBRE'), findsOneWidget);
    });

    testWidgets('shows at midnight with the app open', (tester) async {
      var now = DateTime(2026, 10, 27, 23, 59);
      await _pump(tester, prefs: doneDay1, clock: () => now);
      expect(find.text('Listo por hoy.'), findsOneWidget);
      now = DateTime(2026, 10, 28, 0, 0, 1);
      await tester.pump(const Duration(minutes: 1, seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('SEGUIR A JESÚS · DÍA 2 DE 5'), findsOneWidget);
    });

    testWidgets('shows after a pull to refresh', (tester) async {
      var now = DateTime(2026, 10, 27, 23, 59);
      await _pump(tester, prefs: doneDay1, clock: () => now);
      now = DateTime(2026, 10, 28, 7);
      await tester.fling(find.byType(Scrollable).first, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(find.text('SEGUIR A JESÚS · DÍA 2 DE 5'), findsOneWidget);
    });
  });

  testWidgets('a failed load offers a retry', (tester) async {
    var fail = true;
    await _pump(tester, newest: () async {
      if (fail) throw Exception('offline');
      return PublicStudy.fromJson(_json());
    });
    expect(find.text('Reintentar'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('SEGUIR A JESÚS · DÍA 1 DE 5'), findsOneWidget);
  });

  testWidgets('while the study loads Hoy shows skeletons, not a spinner', (tester) async {
    await _pump(tester, newest: () => Completer<PublicStudy?>().future, settle: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(Skeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('the hero card carries the day\'s hero tag', (tester) async {
    await _pump(tester);
    expect(find.byWidgetPredicate((w) => w is Hero && w.tag == dayHeroTag('study-1', 1)), findsOneWidget);
  });

  testWidgets('the reader has the hero header on its first frame, before the study loads', (tester) async {
    await _pump(
      tester,
      overrides: [studyProvider.overrideWith((ref, key) => Completer<PublicStudy?>().future)],
      reader: (s) => ReaderPage(
        church: _church,
        slug: s.pathParameters['slug']!,
        dayNumber: int.parse(s.pathParameters['n']!),
        initialStudy: ReaderEntry.from(s.extra)?.study,
      ),
    );
    await tester.tap(find.byType(HeroCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(Skeleton), findsNothing);
    final hero = find.byWidgetPredicate((w) => w is Hero && w.tag == dayHeroTag('study-1', 1));
    expect(find.descendant(of: find.byType(ReaderPage), matching: hero), findsOneWidget);
    expect(find.descendant(of: find.byType(ReaderPage), matching: find.text('Idea principal 1')), findsOneWidget);
  });

  testWidgets('tapping the hero card opens the day in the reader', (tester) async {
    await _pump(tester);
    await _tap(tester, find.byType(HeroCard));
    expect(find.text('READER seguir 1'), findsOneWidget);
  });

  testWidgets('ticking a part plays a tick haptic and finishing the day plays success', (tester) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add((call.arguments as String).split('.').last);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await _pump(tester);
    await _tap(tester, find.byKey(const ValueKey('tick-reading')));
    await _tap(tester, find.byKey(const ValueKey('tick-reflection')));
    expect(haptics.where((h) => h == 'lightImpact'), hasLength(2));
    expect(haptics, isNot(contains('mediumImpact')));
    await _tap(tester, find.byKey(const ValueKey('tick-prayer')));
    expect(haptics.where((h) => h == 'mediumImpact'), hasLength(1));
  });

  testWidgets('Hoy fits at 200% text size', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(tester, textScale: 2);
    expect(tester.takeException(), isNull);
  });

  ChurchEvent event(String title, DateTime start) => ChurchEvent(
        uid: title,
        title: title,
        startsAt: start.toUtc(),
        endsAt: start.add(const Duration(hours: 2)).toUtc(),
        localStart: start,
        localEnd: start.add(const Duration(hours: 2)),
        allDay: false,
      );
  final twoEvents = [event('Culto de oración', DateTime(2026, 10, 29, 19)), event('Reunión de jóvenes', DateTime(2026, 10, 31, 18))];
  const desktop = Size(1280, 900);

  testWidgets('Hoje on desktop puts the week beside the day', (tester) async {
    await _pump(tester, size: desktop, platform: TargetPlatform.android, overrides: [
      upcomingEventsProvider.overrideWith((ref, id) async => twoEvents),
    ]);
    expect(tester.getTopLeft(find.byKey(const ValueKey('week'))).dx, greaterThan(tester.getTopRight(find.byType(HeroCard)).dx));
  });

  testWidgets('Hoje on desktop lists upcoming events in the side column', (tester) async {
    await _pump(tester, size: desktop, platform: TargetPlatform.android, overrides: [
      upcomingEventsProvider.overrideWith((ref, id) async => twoEvents),
    ]);
    expect(find.text('Culto de oración'), findsOneWidget);
    expect(find.text('Reunión de jóvenes'), findsOneWidget);
  });

  testWidgets('Hoje on desktop with no events has no events section', (tester) async {
    await _pump(tester, size: desktop, platform: TargetPlatform.android, overrides: [
      upcomingEventsProvider.overrideWith((ref, id) async => const []),
    ]);
    expect(find.text(AppLocalizations.of(tester.element(find.byType(TodayPage)))!.eventsLater), findsNothing);
  });

  testWidgets('Hoje on a phone is unchanged', (tester) async {
    await _pump(tester, size: const Size(390, 844), platform: TargetPlatform.android, overrides: [
      upcomingEventsProvider.overrideWith((ref, id) async => twoEvents),
    ]);
    expect(find.text('Culto de oración'), findsNothing);
    expect(tester.getTopLeft(find.byKey(const ValueKey('week'))).dy, lessThan(tester.getTopLeft(find.byType(HeroCard)).dy));
  });

  group('walking the week', () {
    bool selected(WidgetTester tester, int i) =>
        tester.widget<Semantics>(find.byKey(ValueKey('week-$i'))).properties.selected ?? false;

    testWidgets('tapping Monday shows the day worked on Monday titled with its weekday', (tester) async {
      // Thursday, so Monday is not yesterday.
      await _pump(tester, clock: () => DateTime(2026, 10, 29, 9), prefs: {
        'progress:study-1': '{"1":{"parts":["reading","reflection","prayer"],"doneOn":"2026-10-26",'
            '"partsOn":{"reading":"2026-10-26","reflection":"2026-10-26","prayer":"2026-10-26"}},'
            '"2":{"parts":["reading"],"doneOn":null,"partsOn":{"reading":"2026-10-29"}}}',
      });
      expect(find.text('Día 2 del camino'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('week-0')));
      expect(find.text('Día 1 del camino'), findsOneWidget);
      expect(find.text('Día 2 del camino'), findsNothing);
      expect(find.text('Lunes'), findsWidgets);
      expect(find.text('Hoy'), findsNothing);
      expect(selected(tester, 0), isTrue);
      // Day 1 was finished that Monday, so it rests in its finished state.
      expect(find.text('Día completo.'), findsOneWidget);
      final line = tester.widget<FinishLine>(find.byType(FinishLine));
      expect(line.past, isTrue);
      expect(line.animate, isFalse);
    });

    for (final (language, word) in [('es', 'Ayer'), ('pt', 'Ontem'), ('en', 'Yesterday')]) {
      testWidgets('tapping yesterday titles the page Yesterday in $language', (tester) async {
        await _pump(tester, language: language);
        await _tap(tester, find.byKey(const ValueKey('week-0')));
        expect(find.text(word), findsWidgets);
      });
    }

    testWidgets('a past date with nothing done shows the day Today shows', (tester) async {
      await _pump(tester, prefs: {
        'progress:study-1': '{"1":{"parts":["reading","reflection","prayer"],"doneOn":"2026-10-20"}}',
      });
      expect(find.text('Día 2 del camino'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('week-0')));
      expect(find.text('Día 2 del camino'), findsOneWidget);
      expect(find.text('No es tarde. Aún puedes terminar este día.'), findsOneWidget);
    });

    testWidgets('a past date with nothing done shows the first unfinished day when today\'s is finished', (tester) async {
      await _pump(tester, prefs: {
        'progress:study-1': '{"1":{"parts":["reading","reflection","prayer"],"doneOn":"2026-10-27",'
            '"partsOn":{"reading":"2026-10-27","reflection":"2026-10-27","prayer":"2026-10-27"}}}',
      });
      expect(find.text('Día 1 del camino'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('week-0')));
      expect(find.text('Día 2 del camino'), findsOneWidget);
      expect(find.text('Día 1 del camino'), findsNothing);
      expect(find.text('No es tarde. Aún puedes terminar este día.'), findsOneWidget);
      expect(find.byType(FinishLine), findsNothing);
    });

    testWidgets('a tick on a picked date lands on that date even after midnight passes', (tester) async {
      var now = DateTime(2026, 10, 27, 23, 59);
      await _pump(tester, clock: () => now);
      await _tap(tester, find.byKey(const ValueKey('week-0')));
      // Midnight passes with the app open, before Today's refresh runs.
      now = DateTime(2026, 10, 28, 0, 0, 0, 500);
      await _tap(tester, find.byKey(const ValueKey('tick-reading')));
      final ticks = await loadTicksByDate();
      expect(ticks['2026-10-26']?.parts, {DayPart.reading});
      expect(ticks['2026-10-28'], isNull);
      expect(ticks['2026-10-27'], isNull);
    });

    testWidgets('ticks made on a past date fill that date and say Not too late until done', (tester) async {
      await _pump(tester);
      await _tap(tester, find.byKey(const ValueKey('week-0')));
      await _tap(tester, find.byKey(const ValueKey('tick-reading')));
      final ticks = await loadTicksByDate();
      expect(ticks['2026-10-26']?.parts, {DayPart.reading});
      expect(ticks['2026-10-27'], isNull);
      expect(find.text('No es tarde. Aún puedes terminar este día.'), findsOneWidget);
      expect(find.byType(FinishLine), findsNothing);
      await _tap(tester, find.byKey(const ValueKey('tick-reflection')));
      await _tap(tester, find.byKey(const ValueKey('tick-prayer')));
      expect(find.text('No es tarde. Aún puedes terminar este día.'), findsNothing);
      expect(find.text('Día completo.'), findsOneWidget);
      expect(find.text('Nada perdido.'), findsOneWidget);
      expect((await loadProgress('study-1')).days[1]?.doneOn, '2026-10-26');
      expect(find.descendant(of: find.byKey(const ValueKey('week-0')), matching: find.byIcon(Icons.check)), findsOneWidget);
    });

    double shift(WidgetTester tester, String date) => tester
        .widget<Transform>(find.ancestor(of: find.byKey(ValueKey(date)), matching: find.byType(Transform)).first)
        .transform
        .getTranslation()
        .x;

    testWidgets('the content slides the way the selection moves', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('week-0')));
      await tester.pump();
      await tester.pump(Motion.daySwitch ~/ 2);
      // An earlier date comes in from the left while today leaves to the right.
      expect(shift(tester, '2026-10-26'), lessThan(0));
      expect(shift(tester, '2026-10-27'), greaterThan(0));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('week-1')));
      await tester.pump();
      await tester.pump(Motion.daySwitch ~/ 2);
      expect(shift(tester, '2026-10-27'), greaterThan(0));
      await tester.pumpAndSettle();
    });

    testWidgets('with Reduce Motion the content only fades', (tester) async {
      await _pump(tester, reduceMotion: true);
      await tester.tap(find.byKey(const ValueKey('week-0')));
      await tester.pump();
      await tester.pump(Motion.daySwitch ~/ 2);
      expect(find.ancestor(of: find.byKey(const ValueKey('2026-10-26')), matching: find.byType(FadeTransition)), findsWidgets);
      final moved = find.ancestor(of: find.byKey(const ValueKey('2026-10-26')), matching: find.byType(Transform));
      for (final t in tester.widgetList<Transform>(moved)) {
        expect(t.transform.getTranslation().x, 0);
      }
      await tester.pumpAndSettle();
    });

    testWidgets('the selection returns to today when Today refreshes on a new day', (tester) async {
      var now = DateTime(2026, 10, 27, 23, 59);
      await _pump(tester, clock: () => now);
      await _tap(tester, find.byKey(const ValueKey('week-0')));
      expect(selected(tester, 0), isTrue);
      expect(find.text('Ayer'), findsWidgets);
      // Left open over midnight: Today's midnight refresh moves the selection to the new today.
      now = DateTime(2026, 10, 28, 0, 0, 1);
      await tester.pump(const Duration(minutes: 1, seconds: 1));
      await tester.pumpAndSettle();
      expect(selected(tester, 0), isFalse);
      expect(selected(tester, 2), isTrue);
      expect(find.text('Hoy'), findsWidgets);
    });
  });

  test('the just-finished mark clears when the picked date changes or Today refreshes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(justFinishedProvider, (_, _) {});
    container.read(justFinishedProvider.notifier).set((studyId: 'study-1', day: 1));
    container.read(selectedDateProvider.notifier).select('2026-10-26');
    expect(container.read(justFinishedProvider), isNull);
    container.read(justFinishedProvider.notifier).set((studyId: 'study-1', day: 1));
    container.read(todayRefreshProvider.notifier).bump();
    expect(container.read(justFinishedProvider), isNull);
  });

  testWidgets('a reader opened from a past date ticks that date and its pill goes back to it', (tester) async {
    await _pump(
      tester,
      size: const Size(390, 844),
      overrides: [studyProvider.overrideWith((ref, key) async => PublicStudy.fromJson(_json()))],
      reader: (s) {
        final entry = ReaderEntry.from(s.extra);
        return ReaderPage(
          church: _church,
          slug: s.pathParameters['slug']!,
          dayNumber: int.parse(s.pathParameters['n']!),
          initialStudy: entry?.study,
          fromToday: entry?.fromToday ?? false,
          on: entry?.on,
        );
      },
    );
    await _tap(tester, find.byKey(const ValueKey('week-0')));
    await _tap(tester, find.byType(HeroCard));
    expect(find.byType(ReaderPage), findsOneWidget);
    for (final part in ['reading', 'reflection', 'prayer']) {
      await tester.tap(find.byKey(ValueKey('dock-$part')));
      await tester.pumpAndSettle();
    }
    final ticks = await loadTicksByDate();
    expect(ticks['2026-10-26']?.complete, isTrue);
    expect(ticks['2026-10-27'], isNull);
    await tester.tap(find.text('Día completo · volver a Hoy'));
    await tester.pumpAndSettle();
    // Back on Today, still on that date, where the day rests finished.
    expect(find.byType(ReaderPage), findsNothing);
    expect(find.text('Ayer'), findsWidgets);
    expect(find.text('Día completo.'), findsOneWidget);
  });

  group('moment A', () {
    /// Taps the last tick and pumps frame by frame until the finish line first appears.
    Future<void> finish(WidgetTester tester) async {
      await _tap(tester, find.byKey(const ValueKey('tick-reading')));
      await _tap(tester, find.byKey(const ValueKey('tick-reflection')));
      await tester.tap(find.byKey(const ValueKey('tick-prayer')));
      for (var i = 0; i < 30 && find.byType(FinishLine).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    double lineOpacity(WidgetTester tester) => tester
        .widget<Opacity>(find.descendant(of: find.byType(FinishLine), matching: find.byType(Opacity)).first)
        .opacity;

    double glowOpacity(WidgetTester tester) => tester.widget<Opacity>(find.byKey(const ValueKey('hero-glow'))).opacity;

    testWidgets('finishing today plays moment A once', (tester) async {
      await _pump(tester);
      await finish(tester);
      final line = tester.widget<FinishLine>(find.byType(FinishLine));
      expect(line.animate, isTrue);
      expect(line.past, isFalse);
      final card = tester.widget<HeroCard>(find.byType(HeroCard));
      expect(card.glow, isTrue);
      expect(card.animateGlow, isTrue);
      expect(lineOpacity(tester), lessThan(0.01));
      await tester.pumpAndSettle();
      // It plays through even though Today has cleared the moment.
      expect(lineOpacity(tester), 1);
      expect(glowOpacity(tester), 1);
      expect(tester.widget<FinishLine>(find.byType(FinishLine)).animate, isFalse);
      expect(tester.widget<HeroCard>(find.byType(HeroCard)).animateGlow, isFalse);

      // Opening Today again shows the settled state.
      final saved = (await SharedPreferences.getInstance()).getString('progress:study-1')!;
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, prefs: {'progress:study-1': saved}, settle: false);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.byType(FinishLine), findsOneWidget);
      expect(tester.widget<FinishLine>(find.byType(FinishLine)).animate, isFalse);
      expect(lineOpacity(tester), 1);
      final again = tester.widget<HeroCard>(find.byType(HeroCard));
      expect(again.glow, isTrue);
      expect(again.animateGlow, isFalse);
      expect(glowOpacity(tester), 1);
    });

    testWidgets('moment A is instant with Reduce Motion', (tester) async {
      await _pump(tester, reduceMotion: true);
      await finish(tester);
      expect(tester.widget<FinishLine>(find.byType(FinishLine)).animate, isTrue);
      expect(lineOpacity(tester), 1);
      expect(glowOpacity(tester), 1);
    });
  });

  group('the finished-study quote', () {
    final allDone = {
      'read:study-1': ['1', '2', '3', '4', '5'],
    };
    final study = _json(summary: {
      'main_passage': 'Juan 15:1-8',
      'key_takeaways': ['Permanecer en Él da fruto'],
    });
    double word(WidgetTester tester, int i) => tester.widget<FadeTransition>(find.byKey(ValueKey('quote-word-$i'))).opacity.value;

    testWidgets('sets in word by word', (tester) async {
      await _pump(tester, study: study, prefs: allDone, settle: false);
      for (var i = 0; i < 30 && find.byType(SettleWords).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      for (var i = 0; i < 5; i++) {
        expect(find.byKey(ValueKey('quote-word-$i')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('quote-word-5')), findsNothing);
      await tester.pump(Motion.medium);
      expect(word(tester, 0), 1);
      expect(word(tester, 4), lessThan(1));
      expect(word(tester, 1), greaterThan(word(tester, 4)));
      await tester.pumpAndSettle();
      expect(word(tester, 4), 1);
    });

    testWidgets('is one line of text with Reduce Motion', (tester) async {
      await _pump(tester, study: study, prefs: allDone, reduceMotion: true);
      expect(find.text('Permanecer en Él da fruto'), findsOneWidget);
      expect(find.byKey(const ValueKey('quote-word-0')), findsNothing);
    });
  });
}
