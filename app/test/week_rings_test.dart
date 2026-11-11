import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/app/theme.dart';
import 'package:selah/src/data/progress.dart';
import 'package:selah/src/features/today/week_rings.dart';

void main() {
  // Tuesday 27 October 2026; the week runs Mon 26 Oct to Sun 1 Nov.
  final now = DateTime(2026, 10, 27, 9);

  Widget host(Widget child, {bool reduce = false, double textScale = 1, double width = 390}) => MaterialApp(
    theme: selahLightTheme(),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduce, textScaler: TextScaler.linear(textScale)),
      child: c!,
    ),
    home: Scaffold(body: Center(child: SizedBox(width: width, child: child))),
  );

  Widget rings(Map<String, DateTicks> ticks, {String? selected, ValueChanged<String>? onSelect}) => WeekRings(
    ticks: ticks,
    now: now,
    selected: selected ?? '2026-10-27',
    onSelect: onSelect ?? (_) {},
  );

  Finder arcsIn(Finder within) =>
      find.descendant(of: within, matching: find.byWidgetPredicate((w) => w is CustomPaint && w.painter is RingArcPainter));

  List<DayPart> tickedArcs(WidgetTester tester, Finder within) => [
    for (final e in tester.widgetList<CustomPaint>(arcsIn(within)))
      if ((e.painter! as RingArcPainter).ticked) (e.painter! as RingArcPainter).part,
  ];

  testWidgets('a date with reading ticked paints one coloured arc', (tester) async {
    await tester.pumpWidget(
      host(
        rings({
          '2026-10-26': const DateTicks(parts: {DayPart.reading}, complete: false, lastDay: null),
        }),
      ),
    );
    await tester.pumpAndSettle();
    final monday = find.byKey(const ValueKey('week-0'));
    expect(arcsIn(monday), findsNWidgets(3));
    expect(tickedArcs(tester, monday), [DayPart.reading]);
    // Another day has none.
    expect(tickedArcs(tester, find.byKey(const ValueKey('week-1'))), isEmpty);
  });

  testWidgets('arcs use the part colour when ticked and a pale neutral otherwise', (tester) async {
    await tester.pumpWidget(
      host(
        rings({
          '2026-10-26': const DateTicks(parts: {DayPart.reflection}, complete: false, lastDay: null),
        }),
      ),
    );
    await tester.pumpAndSettle();
    final ctx = tester.element(find.byKey(const ValueKey('week-0')));
    final painters = [
      for (final e in tester.widgetList<CustomPaint>(arcsIn(find.byKey(const ValueKey('week-0')))))
        e.painter! as RingArcPainter,
    ];
    final reflection = painters.firstWhere((p) => p.part == DayPart.reflection);
    expect(reflection.color, ctx.partPalette.reflection.color);
    expect(reflection.progress, 1);
    final reading = painters.firstWhere((p) => p.part == DayPart.reading);
    expect(reading.progress, 0);
    expect(reading.track, isNot(ctx.partPalette.reading.color));
  });

  testWidgets('a complete date shows a check, only on that day', (tester) async {
    await tester.pumpWidget(
      host(
        rings({
          '2026-10-27': const DateTicks(parts: {DayPart.reading, DayPart.reflection, DayPart.prayer}, complete: true, lastDay: null),
        }),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const ValueKey('week-1')), matching: find.byIcon(Icons.check)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('week-0')), matching: find.byIcon(Icons.check)), findsNothing);
  });

  testWidgets('a two-part day that is complete shows a full ring', (tester) async {
    await tester.pumpWidget(
      host(
        rings({
          '2026-10-27': const DateTicks(parts: {DayPart.reading, DayPart.reflection}, complete: true, lastDay: null),
        }),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const ValueKey('week-1')), matching: find.byIcon(Icons.check)), findsOneWidget);
  });

  testWidgets('future days cannot be selected', (tester) async {
    final picked = <String>[];
    await tester.pumpWidget(host(rings({}, onSelect: picked.add)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('week-5')), warnIfMissed: false);
    await tester.pump();
    expect(picked, isEmpty);
    final opacity = tester.widget<Opacity>(find.descendant(of: find.byKey(const ValueKey('week-5')), matching: find.byType(Opacity)));
    expect(opacity.opacity, 0.4);
  });

  testWidgets('tapping yesterday selects it with a selection haptic', (tester) async {
    final calls = <Object?>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final picked = <String>[];
    await tester.pumpWidget(host(rings({}, onSelect: picked.add)));
    await tester.tap(find.byKey(const ValueKey('week-0')));
    await tester.pump();
    expect(picked, ['2026-10-26']);
    expect(calls, ['HapticFeedbackType.selectionClick']);
  });

  testWidgets('tapping the selected day does nothing', (tester) async {
    final picked = <String>[];
    await tester.pumpWidget(host(rings({}, onSelect: picked.add)));
    await tester.tap(find.byKey(const ValueKey('week-1')));
    await tester.pump();
    expect(picked, isEmpty);
  });

  testWidgets('the selected day sits on a surface pill', (tester) async {
    await tester.pumpWidget(host(rings({})));
    final ctx = tester.element(find.byKey(const ValueKey('week-1')));
    bool hasPill(int i) => find
        .descendant(
          of: find.byKey(ValueKey('week-$i')),
          matching: find.byWidgetPredicate(
            (w) => w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color == ctx.tones.surface,
          ),
        )
        .evaluate()
        .isNotEmpty;
    expect(hasPill(1), isTrue);
    expect(hasPill(0), isFalse);
  });

  testWidgets('arcs sweep in over time, and instantly with Reduce Motion', (tester) async {
    double reading(WidgetTester t) => t
        .widgetList<CustomPaint>(arcsIn(find.byType(PartRing)))
        .map((e) => e.painter! as RingArcPainter)
        .firstWhere((p) => p.part == DayPart.reading)
        .progress;

    Widget ring(Set<DayPart> parts, bool reduce) =>
        host(Center(child: PartRing(parts: parts, complete: false)), reduce: reduce);

    await tester.pumpWidget(ring({}, false));
    await tester.pumpWidget(ring({DayPart.reading}, false));
    await tester.pump(const Duration(milliseconds: 60));
    expect(reading(tester), inExclusiveRange(0, 1.5));
    expect(reading(tester), isNot(1));
    await tester.pumpAndSettle();
    expect(reading(tester), 1);

    await tester.pumpWidget(ring({}, true));
    await tester.pumpWidget(ring({DayPart.reading}, true));
    expect(reading(tester), 1); // no sweep: it changes at once
  });

  testWidgets('week rings fit at 200% text on a 320pt-wide screen', (tester) async {
    await tester.pumpWidget(
      host(
        rings({
          '2026-10-26': const DateTicks(parts: {DayPart.reading}, complete: false, lastDay: null),
          '2026-10-27': const DateTicks(parts: {DayPart.reading, DayPart.reflection, DayPart.prayer}, complete: true, lastDay: null),
        }),
        textScale: 2,
        width: 320,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
