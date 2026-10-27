import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/l10n/app_localizations_es.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/data/repository.dart';
import 'package:selah/src/features/admin/church_settings_page.dart';

const _church = Church(
  id: 'A',
  slug: 'vida-nueva',
  name: 'Iglesia Vida Nueva',
  defaultSermonLanguage: 'es',
  defaultOutputLanguage: 'es',
  defaultBibleVersionCode: 'RVR1960',
  defaultDevotionalDays: 5,
  monthlySermonLimit: 4,
);

class _FakeRepository implements SelahRepository {
  final updates = <Map<String, dynamic>>[];

  @override
  Future<void> updateChurch(String churchId, Map<String, dynamic> fields) async =>
      updates.add({'id': churchId, ...fields});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeRepository> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = _FakeRepository();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(fake),
      userIdProvider.overrideWith((ref) => Stream.value('user-1')),
      churchRoleProvider('A').overrideWith((ref) async => ChurchRole.owner),
      churchProvider('vida-nueva').overrideWith((ref) async => _church),
      bibleVersionsProvider.overrideWith((ref) async => [
            {'code': 'RVR1960', 'name': 'Reina-Valera 1960', 'language': 'es'},
          ]),
    ],
    child: MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ChurchSettingsPage(church: _church),
    ),
  ));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  final es = AppLocalizationsEs();

  testWidgets('saves all five fields and shows the slug read-only', (tester) async {
    final fake = await _pump(tester);
    expect(find.text('vida-nueva'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Vida Nueva Centro');
    await tester.tap(find.text(es.save));
    await tester.pumpAndSettle();
    expect(fake.updates, [
      {
        'id': 'A',
        'name': 'Vida Nueva Centro',
        'default_sermon_language': 'es',
        'default_output_language': 'es',
        'default_bible_version_code': 'RVR1960',
        'default_devotional_days': 5,
      }
    ]);
    expect(find.text(es.saved), findsOneWidget);
  });

  testWidgets('rejects a name that is too short', (tester) async {
    final fake = await _pump(tester);
    await tester.enterText(find.byType(TextFormField).first, ' a ');
    await tester.tap(find.text(es.save));
    await tester.pumpAndSettle();
    expect(find.text(es.churchNameInvalid), findsOneWidget);
    expect(fake.updates, isEmpty);
  });
}
