import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/features/study/reader_page.dart';
import 'package:selah/src/features/study/study_page.dart';
import 'package:selah/src/l10n/locale.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _day(int n, {String lang = 'es'}) => {
      'day_number': n,
      'title': lang == 'es' ? 'Título día $n' : 'Day $n title',
      'bible_reading': lang == 'es' ? 'Salmos 27:$n' : 'Psalms 27:$n',
      'main_idea': 'Idea $n',
      'reflection': 'Reflexión $n',
      'questions': <String>[],
    };

final _json = {
  'id': 'study-1',
  'slug': 'retiro-espiritual',
  'title': 'La necesidad del retiro espiritual',
  'central_message': 'Mensaje central',
  'number_of_days': 2,
  'bible_version_code': 'RVR1960',
  'output_language': 'es',
  'published_at': '2026-10-18T10:00:00Z',
  'summary': {'introduction': 'Introducción'},
  'sermons': {
    'youtube_video_id': 'Bflib6PHb68',
    'title': 'Eliseo',
    'preacher': 'Ángel Álvarez',
    'channel': 'Iglesia',
    'thumbnail_url': null,
    'sermon_date': null,
  },
  'devotional_days': [_day(1), _day(2)],
  'study_translations': [
    {
      'language': 'en',
      'title': 'The need for a spiritual retreat',
      'central_message': 'Central message',
      'summary': {'introduction': 'Introduction'},
      'days': [_day(1, lang: 'en'), _day(2, lang: 'en')],
      'bible_version_code': 'NIV',
    },
  ],
};

Future<void> _pump(WidgetTester tester, String language, String location) async {
  SharedPreferences.setMockInitialValues({});
  final router = GoRouter(initialLocation: location, routes: [
    GoRoute(path: '/studies/:slug', builder: (_, s) => StudyPage(slug: s.pathParameters['slug']!)),
    GoRoute(
      path: '/studies/:slug/day/:number',
      builder: (_, s) => ReaderPage(slug: s.pathParameters['slug']!, dayNumber: int.parse(s.pathParameters['number']!)),
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      savedLanguageProvider.overrideWithValue(language),
      studyProvider.overrideWith((ref, slug) async => PublicStudy.fromJson(_json)),
    ],
    child: Consumer(
      builder: (context, ref, _) => MaterialApp.router(
        routerConfig: router,
        locale: ref.watch(appLocaleProvider),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  const reader = '/studies/retiro-espiritual/day/1';

  testWidgets('English reader shows the translated day and the notice', (tester) async {
    await _pump(tester, 'en', reader);
    expect(find.text('Day 1 title'), findsOneWidget);
    expect(find.text('Automatic translation from the original in Spanish.'), findsOneWidget);
  });

  testWidgets('Show original switches to Spanish', (tester) async {
    await _pump(tester, 'en', reader);
    await tester.tap(find.text('Show original'));
    await tester.pumpAndSettle();
    expect(find.text('Título día 1'), findsOneWidget);
    expect(find.text('Show translation'), findsOneWidget);
  });

  testWidgets('missing translation shows Spanish with a note', (tester) async {
    await _pump(tester, 'pt', reader);
    expect(find.text('Título día 1'), findsOneWidget);
    expect(find.text('Este estudo ainda não está disponível em português.'), findsOneWidget);
  });

  testWidgets('Spanish reader sees no banner', (tester) async {
    await _pump(tester, 'es', reader);
    expect(find.text('Título día 1'), findsOneWidget);
    expect(find.textContaining('Traducción automática'), findsNothing);
  });

  testWidgets('English reading link uses NIV', (tester) async {
    await _pump(tester, 'en', reader);
    expect(find.text('Read Psalms 27:1 (NIV)'), findsOneWidget);
  });
}
