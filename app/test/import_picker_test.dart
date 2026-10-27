import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/app/app.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/data/repository.dart';
import 'package:selah/src/features/admin/import_page.dart';

const _church = {'channel_id': 'UC1', 'title': 'Iglesia Vida Nueva', 'handle': '@vidanueva', 'thumbnail_url': null};

class _FakeRepository implements SelahRepository {
  final calls = <String>[];
  final _results = <String, Map<String, dynamic>>{
    'channel_search': {
      'channels': [_church],
    },
    'channel_lives': {
      'lives': [
        {
          'youtube_video_id': 'abc',
          'youtube_url': 'https://www.youtube.com/watch?v=abc',
          'title': 'Culto dominical',
          'thumbnail_url': 'https://i.ytimg.com/vi/abc/mqdefault.jpg',
          'started_at': '2026-10-25T14:00:00Z',
          'duration_seconds': 6300,
        },
      ],
      'next_page_token': 'p2',
    },
    'probe': {
      'youtube_video_id': 'abc',
      'title': 'Culto dominical',
      'channel': 'Iglesia Vida Nueva',
      'thumbnail_url': 'https://i.ytimg.com/vi/abc/hqdefault.jpg',
      'languages': [
        {'language_code': 'es', 'language': 'Spanish', 'is_generated': true},
      ],
    },
  };

  @override
  Future<String> createJob(String step, Map<String, dynamic> payload, {String? sermonId}) async {
    calls.add('job:$step:$payload');
    return step;
  }

  @override
  Future<Job> job(String id) async =>
      Job(id: id, step: id, status: 'succeeded', payload: const {}, result: _results[id], createdAt: DateTime(2026));

  @override
  Future<void> rememberChannel(Map<String, dynamic> channel) async => calls.add('remember:${channel['channel_id']}');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeRepository> _pump(WidgetTester tester, {List<Map<String, dynamic>> recent = const []}) async {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = _FakeRepository();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(fake),
      userIdProvider.overrideWith((ref) => Stream.value('admin')),
      isAdminProvider.overrideWith((ref) async => true),
      recentChannelsProvider.overrideWith((ref) async => recent),
      churchSettingsProvider.overrideWith((ref) async => {
            'default_sermon_language': 'es',
            'default_output_language': 'es',
            'default_bible_version_code': 'RVR1960',
            'default_devotional_days': 5,
          }),
      bibleVersionsProvider.overrideWith((ref) async => [
            {'code': 'RVR1960', 'name': 'Reina-Valera 1960', 'language': 'es'},
          ]),
    ],
    child: MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) => inSpanish(context, const ImportPage())),
    ),
  ));
  await tester.pumpAndSettle();
  return fake;
}

/// Lets the page's one-second job polling finish.
Future<void> _waitForJob(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a recent channel lists its lives and picking one loads the video', (tester) async {
    final fake = await _pump(tester, recent: [_church]);
    await tester.tap(find.text('Iglesia Vida Nueva'));
    await _waitForJob(tester);

    expect(find.text('Transmisiones de Iglesia Vida Nueva'), findsOneWidget);
    expect(find.textContaining('01:45:00'), findsOneWidget);
    expect(find.text('Cargar anteriores'), findsOneWidget);

    await tester.tap(find.text('Culto dominical'));
    await _waitForJob(tester);

    expect(fake.calls, [
      'remember:UC1',
      'job:channel_lives:{channel_id: UC1}',
      'job:probe:{url: https://www.youtube.com/watch?v=abc}',
    ]);
    expect(find.text('Generar estudio'), findsOneWidget);
  });

  testWidgets('searching a church by name and opening its channel', (tester) async {
    final fake = await _pump(tester);
    await tester.enterText(find.byType(TextField), 'vida nueva');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await _waitForJob(tester);
    expect(find.text('@vidanueva'), findsOneWidget);

    await tester.tap(find.text('Iglesia Vida Nueva'));
    await _waitForJob(tester);
    expect(fake.calls, [
      'job:channel_search:{query: vida nueva}',
      'remember:UC1',
      'job:channel_lives:{channel_id: UC1}',
    ]);
    expect(find.text('Culto dominical'), findsOneWidget);
  });

  testWidgets('pasting a link is still available', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Pegar un enlace de YouTube'));
    await tester.pumpAndSettle();
    expect(find.text('URL de YouTube'), findsOneWidget);
    expect(find.text('Buscar video'), findsOneWidget);
  });
}
