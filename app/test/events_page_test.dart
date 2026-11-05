import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/l10n/app_localizations_es.dart';
import 'package:selah/src/app/theme.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/data/repository.dart';
import 'package:selah/src/features/events/event_labels.dart';
import 'package:selah/src/features/events/events_page.dart';

const _church = Church(id: 'A', slug: 'icp', name: 'ICP Alcorcón');

ChurchEvent _event(String title, DateTime start, DateTime end, {String? url, bool allDay = false}) => ChurchEvent(
      uid: title,
      title: title,
      startsAt: start.toUtc(),
      endsAt: end.toUtc(),
      localStart: start,
      localEnd: end,
      allDay: allDay,
      location: 'ICP Alcorcón',
      url: url == null ? null : Uri.parse(url),
    );

final _women = _event('Reunión de Mujeres – Mi hermana y amiga en la Fe', DateTime(2026, 11, 14, 17, 30),
    DateTime(2026, 11, 14, 19, 30), url: 'https://icpresbiteriana.com/event/mujeres/');
final _men = _event('Reunión de Hombres – ¿Qué, para qué, cómo y a quién alabamos?', DateTime(2026, 11, 14, 17, 30),
    DateTime(2026, 11, 14, 20), url: 'https://icpresbiteriana.com/event/hombres/');
final _youth = _event('Reunión de jóvenes – Amnón y las consecuencias del pecado', DateTime(2026, 11, 21, 18),
    DateTime(2026, 11, 21, 20), url: 'https://icpresbiteriana.com/event/jovenes/');

class _FakeRepository implements SelahRepository {
  _FakeRepository(this.events);

  final List<ChurchEvent> events;
  int calls = 0;

  @override
  Future<List<ChurchEvent>> upcomingEvents(String churchId) async {
    calls++;
    return events;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<(_FakeRepository, List<Uri>)> _pump(WidgetTester tester, List<ChurchEvent> events) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = _FakeRepository(events);
  final opened = <Uri>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [repositoryProvider.overrideWithValue(fake)],
    child: MaterialApp(
      theme: selahLightTheme(),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: EventsPage(church: _church, open: opened.add, today: DateTime(2026, 11, 12)),
    ),
  ));
  await tester.pumpAndSettle();
  return (fake, opened);
}

void main() {
  final es = AppLocalizationsEs();
  setUpAll(() => initializeDateFormatting('es'));

  group('heroDayLabel', () {
    final today = DateTime(2026, 11, 12);
    test('today and tomorrow', () {
      expect(heroDayLabel(DateTime(2026, 11, 12, 19), today, es), 'Hoy');
      expect(heroDayLabel(DateTime(2026, 11, 13, 9), today, es), 'Mañana');
    });
    test('later this week names the day', () {
      expect(heroDayLabel(DateTime(2026, 11, 14, 17, 30), today, es), 'Este sábado');
    });
    test('further away shows the date', () {
      expect(heroDayLabel(DateTime(2026, 11, 21, 18), today, es), 'sáb 21 nov');
    });
  });

  testWidgets('the next event leads, the rest follow', (tester) async {
    await _pump(tester, [_women, _men, _youth]);
    expect(find.text('ICP ALCORCÓN'), findsOneWidget);
    expect(find.text(es.eventsTitle), findsOneWidget);
    expect(find.text('ESTE SÁBADO'), findsOneWidget);
    expect(find.text(_women.title), findsOneWidget);
    expect(find.text('17:30 – 19:30 · ICP Alcorcón'), findsOneWidget);
    expect(find.text(es.eventsDetails), findsOneWidget);
    expect(find.text(es.eventsLater.toUpperCase()), findsOneWidget);
    expect(find.text(_men.title), findsOneWidget);
    expect(find.text(_youth.title), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('21'), findsOneWidget);
    expect(find.text('sáb'), findsNWidgets(2));
    expect(find.text('18:00 – 20:00'), findsOneWidget);
  });

  testWidgets('tapping opens the event page on the church site', (tester) async {
    final (_, opened) = await _pump(tester, [_women, _men, _youth]);
    await tester.tap(find.text(es.eventsDetails));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_youth.title));
    await tester.pumpAndSettle();
    expect(opened, [_women.url, _youth.url]);
  });

  testWidgets('event without url is not tappable', (tester) async {
    final (_, opened) = await _pump(tester, [
      _event('Culto', DateTime(2026, 11, 15, 12), DateTime(2026, 11, 15, 13)),
      _event('Cena', DateTime(2026, 11, 22, 20), DateTime(2026, 11, 22, 22)),
    ]);
    expect(find.text(es.eventsDetails), findsNothing);
    await tester.tap(find.text('Culto'));
    await tester.tap(find.text('Cena'));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
  });

  testWidgets('an all-day event shows no times', (tester) async {
    await _pump(tester, [
      _event('Retiro', DateTime(2026, 11, 20), DateTime(2026, 11, 21), allDay: true),
    ]);
    expect(find.text('${es.eventsAllDay} · ICP Alcorcón'), findsOneWidget);
    expect(find.textContaining('00:00'), findsNothing);
  });

  testWidgets('pull to refresh reads the events again', (tester) async {
    final (fake, _) = await _pump(tester, [_women, _men, _youth]);
    expect(fake.calls, 1);
    await tester.fling(find.text(es.eventsTitle), const Offset(0, 900), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(fake.calls, 2);
  });
}
