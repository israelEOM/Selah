import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/app/design/art.dart';
import 'package:selah/src/app/app.dart';
import 'package:selah/src/app/theme.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/data/repository.dart';
import 'package:selah/src/features/admin/art_picker.dart';
import 'package:selah/src/features/admin/sermon_page.dart';

const _church = Church(id: 'A', slug: 'vida-nueva', name: 'Iglesia Vida Nueva');

const _library = [
  ArtEntry(key: 'hillside-dawn', tags: [], pickable: true, alt: {'es': 'Amanecer'}),
  ArtEntry(key: 'dove', tags: [], pickable: true, alt: {'es': 'Una paloma'}),
  ArtEntry(key: 'welcome', tags: [], pickable: false, alt: {}),
];

class _FakeRepository implements SelahRepository {
  (String, String?)? studyArt;
  (String, int, String?)? dayArt;

  @override
  Future<void> setStudyArt(String studyId, String? key) async => studyArt = (studyId, key);

  @override
  Future<void> setDayArt(String studyId, int dayNumber, String? key) async => dayArt = (studyId, dayNumber, key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeRepository> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = _FakeRepository();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(fake),
      artLibraryProvider.overrideWith((ref) async => _library),
      userIdProvider.overrideWith((ref) => Stream.value('admin')),
      churchRoleProvider('A').overrideWith((ref) async => ChurchRole.editor),
      // The database as the fake last saved it.
      sermonDetailProvider('s1').overrideWith((ref) async => SermonDetail(
            sermon: {'id': 's1', 'title': 'Sermón', 'youtube_video_id': 'abc', 'church_id': 'A'},
            hasTranscript: true,
            study: {
              'id': 'st1',
              'status': 'review',
              'central_message': 'Mensaje',
              'summary': <String, dynamic>{},
              'number_of_days': 1,
              'art_key': fake.studyArt?.$2,
            },
            days: [
              {
                'day_number': 1,
                'title': 'Día 1',
                'bible_reading': 'Juan 1',
                'questions': <String>[],
                'art_key': fake.dayArt?.$3,
              },
            ],
          )),
      sermonJobsProvider('s1').overrideWith((ref) => Stream.value(const <String, Job>{})),
      adminTranslationsProvider('st1').overrideWith((ref) async => const <Map<String, dynamic>>[]),
    ],
    child: MaterialApp(
      theme: selahLightTheme(),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) => inSpanish(context, const SermonPage(church: _church, sermonId: 's1'))),
    ),
  ));
  await tester.pumpAndSettle();
  return fake;
}

String? _shown(WidgetTester tester, Key key) => tester.widget<SelahArt>(find.byKey(key)).artKey;

void main() {
  testWidgets("changing a study's image saves it and shows it", (tester) async {
    final fake = await _pump(tester);
    await tester.tap(find.text('Cambiar imagen'));
    await tester.pumpAndSettle();
    expect(find.text('Elige una imagen'), findsOneWidget);
    // Only pickable entries are offered.
    expect(find.byKey(const Key('art-tile-welcome')), findsNothing);
    await tester.tap(find.byKey(const Key('art-tile-dove')));
    await tester.pumpAndSettle();
    expect(fake.studyArt, ('st1', 'dove'));
    expect(_shown(tester, const Key('study-art')), 'dove');
  });

  testWidgets("changing a day's image saves it and shows it", (tester) async {
    final fake = await _pump(tester);
    await tester.tap(find.byKey(const Key('day-art-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('art-tile-dove')));
    await tester.pumpAndSettle();
    expect(fake.dayArt, ('st1', 1, 'dove'));
    expect(_shown(tester, const Key('day-art-1')), 'dove');
  });

  testWidgets('dismissing the picker changes nothing', (tester) async {
    final fake = await _pump(tester);
    await tester.tap(find.text('Cambiar imagen'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(fake.studyArt, isNull);
  });

  testWidgets('the current image is ringed', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [artLibraryProvider.overrideWith((ref) async => _library)],
      child: MaterialApp(
        theme: selahLightTheme(),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) => Scaffold(body: TextButton(onPressed: () => showArtPicker(context, current: 'dove'), child: const Text('abrir')))),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('art-current')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('art-tile-dove')), matching: find.byKey(const Key('art-current'))), findsOneWidget);
  });
}
