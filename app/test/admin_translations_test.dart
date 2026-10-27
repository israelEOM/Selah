import 'package:flutter/material.dart';
import 'package:selah/src/app/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/app/app.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/data/repository.dart';
import 'package:selah/src/features/admin/sermon_page.dart';

const _church = Church(id: 'A', slug: 'vida-nueva', name: 'Iglesia Vida Nueva');

class _FakeRepository implements SelahRepository {
  bool failJob = false;
  final calls = <String>[];

  @override
  Future<void> setStudyPublished(String studyId, bool published) async => calls.add('published:$studyId:$published');

  @override
  Future<String> createJob(String step, Map<String, dynamic> payload, {required String churchId, String? sermonId}) async {
    if (failJob) throw Exception('network');
    calls.add('job:$churchId:$step:$payload:$sermonId');
    return 'job-1';
  }

  @override
  Future<void> setTranslationHidden(String id, bool hidden) async => calls.add('hidden:$id:$hidden');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SermonDetail _detail(String status, {String churchId = 'A'}) => SermonDetail(
      sermon: {'id': 's1', 'title': 'Sermón', 'youtube_video_id': 'abc', 'church_id': churchId},
      hasTranscript: true,
      study: {
        'id': 'st1',
        'status': status,
        'title': 'Estudio',
        'central_message': 'Mensaje',
        'summary': <String, dynamic>{},
        'number_of_days': 3,
      },
      days: [
        for (var i = 1; i <= 3; i++)
          {
            'day_number': i,
            'title': 'Día $i',
            'bible_reading': 'Juan $i',
            'main_idea': 'idea',
            'reflection': 'reflexión',
            'application': 'aplicación',
            'questions': ['¿Pregunta?'],
            'prayer': 'oración',
          },
      ],
    );

Map<String, dynamic> _row(String id, {required bool hidden}) => {
      'id': id,
      'study_id': 'st1',
      'language': 'en',
      'title': 'Translated title',
      'central_message': 'Translated message',
      'summary': <String, dynamic>{},
      'days': <Map<String, dynamic>>[],
      'hidden': hidden,
      'created_at': '2026-10-19T10:00:00Z',
    };

Future<_FakeRepository> _pump(
  WidgetTester tester, {
  required String status,
  List<Map<String, dynamic>> rows = const [],
  bool failJob = false,
  String sermonChurchId = 'A',
}) async {
  tester.view.physicalSize = const Size(1000, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = _FakeRepository()..failJob = failJob;
  var reads = 0;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(fake),
      userIdProvider.overrideWith((ref) => Stream.value('admin')),
      churchRoleProvider('A').overrideWith((ref) async => ChurchRole.editor),
      sermonDetailProvider('s1').overrideWith((ref) async {
        // After the first read, a failed-job scenario shows the study as published, as the database now has it.
        reads++;
        return _detail(failJob && reads > 1 ? 'published' : status, churchId: sermonChurchId);
      }),
      sermonJobsProvider('s1').overrideWith((ref) => Stream.value(const <String, Job>{})),
      adminTranslationsProvider('st1').overrideWith((ref) async => rows),
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

void main() {
  testWidgets("another church's sermon is not found under this church", (tester) async {
    await _pump(tester, status: 'review', sermonChurchId: 'B');
    expect(find.text('No encontramos esta iglesia.'), findsOneWidget);
    expect(find.text('Publicar'), findsNothing);
  });

  testWidgets('publishing queues the translation', (tester) async {
    final fake = await _pump(tester, status: 'review');
    await tester.tap(find.text('Publicar'));
    await tester.pumpAndSettle();
    expect(fake.calls, [
      'published:st1:true',
      "job:A:translate:{languages: [en, pt]}:s1",
    ]);
  });

  testWidgets('unpublishing does not translate', (tester) async {
    final fake = await _pump(tester, status: 'published');
    await tester.tap(find.text('Retirar publicación'));
    await tester.pumpAndSettle();
    expect(fake.calls, ['published:st1:false']);
  });

  testWidgets('approving a translation', (tester) async {
    final fake = await _pump(tester, status: 'published', rows: [_row('t1', hidden: true)]);
    expect(find.textContaining('Pendiente de aprobación'), findsOneWidget);
    await tester.tap(find.text('Aprobar'));
    await tester.pumpAndSettle();
    expect(fake.calls, ['hidden:t1:false']);
  });

  testWidgets('withdrawing a translation', (tester) async {
    final fake = await _pump(tester, status: 'published', rows: [_row('t1', hidden: false)]);
    expect(find.textContaining('Publicada'), findsOneWidget);
    await tester.tap(find.text('Retirar'));
    await tester.pumpAndSettle();
    expect(fake.calls, ['hidden:t1:true']);
  });

  testWidgets('a failed translation job after publishing still refreshes and says so', (tester) async {
    final fake = await _pump(tester, status: 'review', failJob: true);
    await tester.tap(find.text('Publicar'));
    await tester.pumpAndSettle();
    expect(fake.calls, ['published:st1:true']);
    expect(find.textContaining('no se pudo iniciar la traducción'), findsOneWidget);
    expect(find.text('Retirar publicación'), findsOneWidget);
    expect(find.text('Traducciones'), findsOneWidget);
  });
}
