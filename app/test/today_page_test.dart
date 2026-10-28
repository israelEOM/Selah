import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/app/theme.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/current_church.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/features/study/reader_page.dart';
import 'package:selah/src/features/today/today_page.dart';
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
}) async {
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
        theme: selahLightTheme(),
        routerConfig: router,
        locale: ref.watch(appLocaleProvider),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
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
    expect(find.text('Hecho por hoy'), findsNothing);
  });

  testWidgets('a day without prayer has no prayer row', (tester) async {
    await _pump(tester, study: _json(days: [for (var i = 1; i <= 5; i++) _day(i, prayer: false)]));
    expect(find.text('Reflexión'), findsOneWidget);
    expect(find.text('Oración'), findsNothing);
  });

  testWidgets('ticking all parts shows Hecho por hoy and Leer el siguiente', (tester) async {
    await _pump(tester);
    for (final part in ['reading', 'reflection', 'prayer']) {
      await _tap(tester, find.byKey(ValueKey('tick-$part')));
    }
    expect(find.text('Hecho por hoy'), findsOneWidget);
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
    expect(find.text('Permanecer en Él da fruto'), findsOneWidget);
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
      expect(find.text('Hecho por hoy'), findsOneWidget);
      now = DateTime(2026, 10, 28, 7);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Hecho por hoy'), findsNothing);
      expect(find.text('SEGUIR A JESÚS · DÍA 2 DE 5'), findsOneWidget);
      expect(find.text('MIÉRCOLES, 28 DE OCTUBRE'), findsOneWidget);
    });

    testWidgets('shows at midnight with the app open', (tester) async {
      var now = DateTime(2026, 10, 27, 23, 59);
      await _pump(tester, prefs: doneDay1, clock: () => now);
      expect(find.text('Hecho por hoy'), findsOneWidget);
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
        initialStudy: s.extra as PublicStudy?,
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
}
