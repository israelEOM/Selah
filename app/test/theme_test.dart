import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/src/app/theme.dart';

void main() {
  test('light scheme uses the church palette', () {
    final t = selahLightTheme();
    expect(t.colorScheme.primary, const Color(0xFF2E4A38));
    expect(t.colorScheme.onSurface, const Color(0xFF0E2341));
    expect(t.scaffoldBackgroundColor, Colors.white);
    expect(t.extension<SelahTones>()!.accent, const Color(0xFFF15A24));
  });

  test('dark scheme is near-black with green accent', () {
    final t = selahDarkTheme();
    final tones = t.extension<SelahTones>()!;
    expect(t.brightness, Brightness.dark);
    expect(t.scaffoldBackgroundColor, const Color(0xFF0B0B0C));
    expect(tones.accent, const Color(0xFF5BC49A));
    expect(tones.done, const Color(0xFFC9A46A));
  });

  testWidgets('UI text uses the system font', (tester) async {
    // Flutter fills in the platform font (Roboto on Android); what matters is
    // that headings are no longer set in the serif.
    expect(selahLightTheme().textTheme.titleLarge!.fontFamily, isNot('Georgia'));
    late TextStyle quote;
    await tester.pumpWidget(
      MaterialApp(
        theme: selahLightTheme(),
        home: Builder(
          builder: (context) {
            quote = serifQuote(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(quote.fontFamily, 'Georgia');
  });
}
