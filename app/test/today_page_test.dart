import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/app/theme.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/current_church.dart';
import 'package:selah/src/data/providers.dart';
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
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final router = GoRouter(initialLocation: '/', routes: [
    GoRoute(path: '/', builder: (_, _) => const TodayPage()),
    GoRoute(path: '/c/vida-nueva', builder: (_, _) => const Text('STUDIES')),
    GoRoute(path: '/c/vida-nueva/studies/:slug', builder: (_, s) => Text('STUDY ${s.pathParameters['slug']}')),
    GoRoute(
      path: '/c/vida-nueva/studies/:slug/day/:n',
      builder: (_, s) => Text('READER ${s.pathParameters['slug']} ${s.pathParameters['n']}'),
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      savedLanguageProvider.overrideWithValue(language),
      currentChurchProvider.overrideWith((ref) async => _church),
      newestStudyProvider.overrideWith((ref, churchId) async => noStudy ? null : PublicStudy.fromJson(study ?? _json())),
      clockProvider.overrideWithValue(() => _now),
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
    expect(find.text('Seguir a Jesús'), findsOneWidget);
    expect(find.text('DEVOCIONAL DE HOY · DÍA 1 DE 5'), findsOneWidget);
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
    expect(find.text('Seguir Jesus'), findsOneWidget);
    expect(find.text('DIA 1 EM PORTUGUÊS'), findsOneWidget);
    expect(find.text('Leitura bíblica'), findsOneWidget);
  });
}
