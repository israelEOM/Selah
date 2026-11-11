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

Future<(_FakeRepository, List<Uri>)> _pump(WidgetTester tester, List<ChurchEvent> events,
    {Size size = const Size(800, 1800), TargetPlatform? platform}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = _FakeRepository(events);
  final opened = <Uri>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [repositoryProvider.overrideWithValue(fake)],
    child: MaterialApp(
      theme: selahLightTheme().copyWith(platform: platform),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: EventsPage(church: _church, open: opened.add, now: DateTime(2026, 11, 12, 10)),
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
    expect(find.text('nov'), findsNWidgets(2));
    expect(find.text('18:00 – 20:00'), findsOneWidget);
  });

  testWidgets('events that arrive out of order still lead with the earliest', (tester) async {
    await _pump(tester, [_youth, _men, _women]);
    expect(find.text('ESTE SÁBADO'), findsOneWidget);
    expect(tester.getTopLeft(find.text(_women.title)).dy, lessThan(tester.getTopLeft(find.text(_youth.title)).dy));
  });

  testWidgets('events that have ended are not shown', (tester) async {
    await _pump(tester, [_event('Ensayo', DateTime(2026, 11, 10, 18), DateTime(2026, 11, 10, 20)), _women]);
    expect(find.text('Ensayo'), findsNothing);
    expect(find.text(_women.title), findsOneWidget);
  });

  testWidgets('when everything has ended the page says so', (tester) async {
    await _pump(tester, [_event('Ensayo', DateTime(2026, 11, 10, 18), DateTime(2026, 11, 10, 20))]);
    expect(find.text('Ensayo'), findsNothing);
    expect(find.text(es.eventsNone), findsOneWidget);
  });

  testWidgets("the next event and a row's sheet open the event page on the church site", (tester) async {
    final (_, opened) = await _pump(tester, [_women, _men, _youth]);
    await tester.tap(find.text(es.eventsDetails));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_youth.title));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text(es.eventsDetails)));
    await tester.pumpAndSettle();
    expect(opened, [_women.url, _youth.url]);
  });

  testWidgets('an event without url has no link to open', (tester) async {
    final (_, opened) = await _pump(tester, [
      _event('Culto', DateTime(2026, 11, 15, 12), DateTime(2026, 11, 15, 13)),
      _event('Cena', DateTime(2026, 11, 22, 20), DateTime(2026, 11, 22, 22)),
    ]);
    expect(find.text(es.eventsDetails), findsNothing);
    await tester.tap(find.text('Culto'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    await tester.tap(find.text('Cena'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text(es.eventsDetails), findsNothing);
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

  testWidgets('nothing on the event hero card is terracotta', (tester) async {
    await _pump(tester, [_women, _men]);
    final accent = selahLightTheme().extension<SelahTones>()!.accent;
    final texts = tester.widgetList<Text>(find.descendant(of: find.byType(HeroCard), matching: find.byType(Text)));
    expect(texts, isNotEmpty);
    expect(texts.where((t) => t.style?.color == accent), isEmpty);
  });

  testWidgets('later events sit in two columns on desktop', (tester) async {
    final later = _event('Culto de oración', DateTime(2026, 11, 28, 19), DateTime(2026, 11, 28, 21));
    await _pump(tester, [_women, _men, _youth, later], size: const Size(1280, 1000), platform: TargetPlatform.android);
    expect(tester.getTopLeft(find.text(_youth.title)).dy, tester.getTopLeft(find.text(_men.title)).dy);
  });

  testWidgets('resizing across 1024 px keeps the scroll position', (tester) async {
    final more = [
      for (var d = 1; d <= 8; d++) _event('Evento $d', DateTime(2026, 11, 20 + d, 19), DateTime(2026, 11, 20 + d, 21)),
    ];
    await _pump(tester, [_women, ...more], size: const Size(1280, 600), platform: TargetPlatform.android);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    final before = tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;
    expect(before, greaterThan(0));
    tester.view.physicalSize = const Size(900, 600);
    await tester.pumpAndSettle();
    expect(tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels, before);
  });

  testWidgets('on a tablet the next event is as wide as the rows below it', (tester) async {
    await _pump(tester, [_women, _men, _youth], size: const Size(900, 1200), platform: TargetPlatform.android);
    final card = tester.getSize(find.byType(HeroCard)).width;
    final row = tester.getSize(find.byType(EventRow).first).width;
    expect(card, row);
  });

  testWidgets('events stick their group heading while scrolling', (tester) async {
    final later = [
      for (var d = 1; d <= 10; d++) _event('Evento $d', DateTime(2026, 11, 20 + d, 19), DateTime(2026, 11, 20 + d, 21)),
    ];
    await _pump(tester, [_women, ...later], size: const Size(390, 844), platform: TargetPlatform.android);
    final heading = find.text(es.eventsLater.toUpperCase());
    final startTop = tester.getTopLeft(heading).dy;
    await tester.drag(find.byType(Scrollable).first, Offset(0, -(startTop + 300)));
    await tester.pumpAndSettle();
    expect(heading.hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(heading).dy, lessThan(160));
  });

  testWidgets('each row has a date tile with the month and the day number', (tester) async {
    await _pump(tester, [_women, _men, _youth], size: const Size(390, 844), platform: TargetPlatform.android);
    expect(find.text('nov'), findsNWidgets(2));
    final month = tester.widget<Text>(find.text('nov').first);
    expect(month.style?.color, selahLightTheme().extension<SelahTones>()!.accent);
    expect(tester.getSize(find.byKey(const ValueKey('event-date-tile')).first), const Size(44, 48));
  });

  testWidgets('the day number counts in on first view', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(_FakeRepository([_women, _youth]))],
      child: MaterialApp(
        theme: selahLightTheme().copyWith(platform: TargetPlatform.android),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EventsPage(church: _church, now: DateTime(2026, 11, 12, 10)),
      ),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('21'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('21'), findsOneWidget);
  });

  testWidgets('tapping an event opens a sheet', (tester) async {
    final (_, opened) = await _pump(tester, [_women, _men, _youth], size: const Size(390, 844),
        platform: TargetPlatform.android);
    await tester.tap(find.text(_youth.title));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text(_youth.title)), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('ICP Alcorcón')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.textContaining('18:00 – 20:00')), findsOneWidget);
    await tester.tap(find.descendant(of: sheet, matching: find.text(es.eventsDetails)));
    await tester.pumpAndSettle();
    expect(opened, [_youth.url]);
  });
}
