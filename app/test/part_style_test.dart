import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/src/app/theme.dart';
import 'package:selah/src/data/progress.dart';
import 'package:selah/src/features/today/part_row.dart';
import 'package:selah/src/features/today/part_style.dart';

void main() {
  Widget host(Widget child, {bool reduce = false}) => MaterialApp(
    theme: selahLightTheme(),
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
      child: c!,
    ),
    home: Scaffold(body: Center(child: child)),
  );

  Widget row(bool ticked, {bool reduce = false}) => host(
    PartRow(part: DayPart.prayer, title: 'Prayer', ticked: ticked, onTick: () {}, onOpen: () {}),
    reduce: reduce,
  );

  testWidgets('PartRow paints its part tint and shows the tick', (tester) async {
    await tester.pumpWidget(row(false));
    final fills = [
      ...tester.widgetList<Ink>(find.byType(Ink)).map((i) => (i.decoration as BoxDecoration).color),
      ...tester
          .widgetList<DecoratedBox>(find.descendant(of: find.byType(PartRow), matching: find.byType(DecoratedBox)))
          .map((d) => (d.decoration as BoxDecoration).color),
    ];
    expect(fills, contains(const Color(0xFFE8E9F2)));
    final tick = tester.getSemantics(find.bySemanticsLabel('Prayer').last);
    expect(tick.flagsCollection.isChecked, isNot(CheckedState.isTrue));
  });

  testWidgets('ticking ripples once without Reduce Motion', (tester) async {
    await tester.pumpWidget(row(false));
    expect(find.byKey(const ValueKey('tick-ripple')), findsNothing);
    await tester.pumpWidget(row(true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('tick-ripple')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tick-ripple')), findsNothing);
  });

  testWidgets('no ripple and no hop with Reduce Motion', (tester) async {
    await tester.pumpWidget(row(false, reduce: true));
    await tester.pumpWidget(row(true, reduce: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('tick-ripple')), findsNothing);
    final hop = tester.widget<Transform>(
      find.descendant(of: find.byType(PartHop), matching: find.byType(Transform)).first,
    );
    expect(hop.transform.storage[0], 1.0);
  });

  testWidgets('PartIcon falls back to an icon when the image is missing', (tester) async {
    await tester.pumpWidget(host(const PartIcon(part: DayPart.reading)));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
  });
}
