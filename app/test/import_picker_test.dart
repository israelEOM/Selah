import 'package:flutter/material.dart';
import 'package:selah/src/app/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/app/app.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/data/repository.dart';
import 'package:selah/src/features/admin/import_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _home = Church(
  id: 'A',
  slug: 'vida-nueva',
  name: 'Iglesia Vida Nueva',
  defaultSermonLanguage: 'es',
  defaultOutputLanguage: 'es',
  defaultBibleVersionCode: 'RVR1960',
  defaultDevotionalDays: 5,
  monthlySermonLimit: 8,
);

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

  bool overLimit = false;

  @override
  Future<String> createJob(String step, Map<String, dynamic> payload, {required String churchId, String? sermonId}) async {
    calls.add('job:$churchId:$step:$payload');
    return step;
  }

  @override
  Future<String> saveSermon(String churchId, Map<String, dynamic> fields) async {
    calls.add('save:$churchId:${fields['youtube_video_id']}');
    if (overLimit) throw const PostgrestException(message: 'monthly_limit_reached');
    return 's1';
  }

  @override
  Future<Job> job(String id) async =>
      Job(id: id, step: id, status: 'succeeded', payload: const {}, result: _results[id], createdAt: DateTime(2026));

  @override
  Future<void> rememberChannel(String churchId, Map<String, dynamic> channel) async =>
      calls.add('remember:$churchId:${channel['channel_id']}');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeRepository> _pump(
  WidgetTester tester, {
  List<Map<String, dynamic>> recent = const [],
  bool overLimit = false,
}) async {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = _FakeRepository()..overLimit = overLimit;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(fake),
      userIdProvider.overrideWith((ref) => Stream.value('admin')),
      churchRoleProvider('A').overrideWith((ref) async => ChurchRole.editor),
      recentChannelsProvider('A').overrideWith((ref) async => recent),
      bibleVersionsProvider.overrideWith((ref) async => [
            {'code': 'RVR1960', 'name': 'Reina-Valera 1960', 'language': 'es'},
          ]),
    ],
    child: MaterialApp(
      theme: selahLightTheme(),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) => inSpanish(context, const ImportPage(church: _home))),
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
      'remember:A:UC1',
      'job:A:channel_lives:{channel_id: UC1}',
      'job:A:probe:{url: https://www.youtube.com/watch?v=abc}',
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
      'job:A:channel_search:{query: vida nueva}',
      'remember:A:UC1',
      'job:A:channel_lives:{channel_id: UC1}',
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

  testWidgets('a church over its monthly limit is told so', (tester) async {
    final fake = await _pump(tester, recent: [_church], overLimit: true);
    await tester.tap(find.text('Iglesia Vida Nueva'));
    await _waitForJob(tester);
    await tester.tap(find.text('Culto dominical'));
    await _waitForJob(tester);
    await tester.tap(find.text('Generar estudio'));
    await tester.pumpAndSettle();

    expect(fake.calls.last, 'save:A:abc');
    expect(find.text('Esta iglesia ya llegó a su límite de 8 predicaciones este mes.'), findsOneWidget);
  });
}
