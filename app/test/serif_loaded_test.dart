import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/src/app/theme.dart';

void main() {
  testWidgets('tests render the real serif, not the placeholder font', (tester) async {
    // The test placeholder font draws every glyph one em wide; Source Serif 4's "i" is far narrower.
    await tester.pumpWidget(MaterialApp(
      theme: selahLightTheme(),
      home: Builder(builder: (context) => Center(child: Text('iiiiiiiiii', style: serifReading(context).copyWith(fontSize: 20)))),
    ));
    expect(tester.getSize(find.text('iiiiiiiiii')).width, lessThan(120));
  });
}
