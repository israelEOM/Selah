import 'package:flutter/material.dart';
import 'package:selah/src/app/theme.dart';
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
  final syncCalls = <String>[];
  EventsSyncResult syncResult = const EventsSynced(4);

  @override
  Future<EventsSyncResult> syncChurchEvents(String churchId) async {
    syncCalls.add(churchId);
    return syncResult;
  }

  @override
  Future<void> updateChurch(String churchId, Map<String, dynamic> fields) async =>
      updates.add({'id': churchId, ...fields});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeRepository> _pump(WidgetTester tester,
    {Church church = _church, EventsSyncResult syncResult = const EventsSynced(4)}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = _FakeRepository()..syncResult = syncResult;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(fake),
      userIdProvider.overrideWith((ref) => Stream.value('user-1')),
      churchRoleProvider('A').overrideWith((ref) async => ChurchRole.owner),
      churchProvider('vida-nueva').overrideWith((ref) async => church),
      bibleVersionsProvider.overrideWith((ref) async => [
            {'code': 'RVR1960', 'name': 'Reina-Valera 1960', 'language': 'es'},
          ]),
    ],
    child: MaterialApp(
      theme: selahLightTheme(),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ChurchSettingsPage(church: church),
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
        'events_calendar_url': null,
        'timezone': 'Europe/Madrid',
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

  Finder calendarField() => find.widgetWithText(TextFormField, es.eventsCalendarLink);

  testWidgets('a new calendar link is saved as https and checked', (tester) async {
    final fake = await _pump(tester);
    await tester.enterText(calendarField(), 'webcal://icpresbiteriana.com/?post_type=tribe_events&ical=1');
    await tester.tap(find.text(es.save));
    await tester.pumpAndSettle();
    expect(fake.updates.single['events_calendar_url'], 'https://icpresbiteriana.com/?post_type=tribe_events&ical=1');
    expect(fake.syncCalls, ['A']);
    expect(find.text(es.eventsFound(4)), findsOneWidget);
  });

  testWidgets('blocked check still saves the link', (tester) async {
    final fake = await _pump(tester, syncResult: const EventsSyncFailed('blocked'));
    await tester.enterText(calendarField(), 'https://icpresbiteriana.com/events/');
    await tester.tap(find.text(es.save));
    await tester.pumpAndSettle();
    expect(fake.updates.single['events_calendar_url'], 'https://icpresbiteriana.com/events/');
    expect(find.text(
        'El sitio web bloquea el acceso automático. Pide al administrador de la web que permita el calendario.'),
        findsOneWidget);
  });

  testWidgets('an unchanged link is not checked again', (tester) async {
    const linked = Church(id: 'A', slug: 'vida-nueva', name: 'Iglesia Vida Nueva',
        eventsCalendarUrl: 'https://a.org/cal.ics');
    final fake = await _pump(tester, church: linked);
    await tester.tap(find.text(es.save));
    await tester.pumpAndSettle();
    expect(fake.updates.single['events_calendar_url'], 'https://a.org/cal.ics');
    expect(fake.syncCalls, isEmpty);
  });

  testWidgets('clearing the link turns the calendar off without a check', (tester) async {
    const linked = Church(id: 'A', slug: 'vida-nueva', name: 'Iglesia Vida Nueva',
        eventsCalendarUrl: 'https://a.org/cal.ics');
    final fake = await _pump(tester, church: linked);
    await tester.enterText(calendarField(), '  ');
    await tester.tap(find.text(es.save));
    await tester.pumpAndSettle();
    expect(fake.updates.single.containsKey('events_calendar_url'), isTrue);
    expect(fake.updates.single['events_calendar_url'], isNull);
    expect(fake.syncCalls, isEmpty);
  });

  testWidgets('a link that is not https is rejected', (tester) async {
    final fake = await _pump(tester);
    await tester.enterText(calendarField(), 'http://a.org/cal.ics');
    await tester.tap(find.text(es.save));
    await tester.pumpAndSettle();
    expect(find.text(es.eventsCalendarInvalid), findsOneWidget);
    expect(fake.updates, isEmpty);
  });

  testWidgets('the timezone can be changed', (tester) async {
    final fake = await _pump(tester);
    await tester.tap(find.text('Europe/Madrid'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Europe/Lisbon').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(es.save));
    await tester.pumpAndSettle();
    expect(fake.updates.single['timezone'], 'Europe/Lisbon');
  });

  testWidgets('shows the last refresh or the last problem', (tester) async {
    await _pump(tester, church: Church(id: 'A', slug: 'vida-nueva', name: 'Iglesia Vida Nueva',
        eventsCalendarUrl: 'https://a.org/cal.ics', eventsSyncedAt: DateTime.utc(2026, 11, 5, 9)));
    expect(find.textContaining('Última actualización:'), findsOneWidget);
    await _pump(tester, church: const Church(id: 'A', slug: 'vida-nueva', name: 'Iglesia Vida Nueva',
        eventsCalendarUrl: 'https://a.org/cal.ics', eventsSyncError: 'unreachable'));
    expect(find.text('No se pudo leer el calendario.'), findsOneWidget);
  });
}
