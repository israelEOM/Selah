import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/src/app/theme.dart';

void main() {
  test('light theme is warm paper with Selah green and terracotta', () {
    final t = selahLightTheme();
    final tones = t.extension<SelahTones>()!;
    expect(t.scaffoldBackgroundColor, const Color(0xFFFAF7F2));
    expect(t.colorScheme.onSurface, const Color(0xFF262320));
    expect(t.colorScheme.primary, const Color(0xFF2F5D4A));
    expect(tones.surface, const Color(0xFFF1EBE1));
    expect(tones.accent, const Color(0xFFB0573A));
    expect(tones.heroStart, const Color(0xFF2F5D4A));
  });

  test('dark theme is warm gray, not black, with sage and terracotta', () {
    final t = selahDarkTheme();
    final tones = t.extension<SelahTones>()!;
    expect(t.scaffoldBackgroundColor, const Color(0xFF1E1C1A));
    expect(t.colorScheme.primary, const Color(0xFFA9CDB8));
    expect(tones.surface, const Color(0xFF272421));
    expect(tones.accent, const Color(0xFFE0906E));
    expect(tones.heroStart, const Color(0xFF26332C));
  });

  testWidgets('headings and reading text use Source Serif 4, UI text does not', (tester) async {
    final text = selahLightTheme().textTheme;
    for (final style in [text.displaySmall, text.headlineMedium, text.headlineSmall, text.titleLarge]) {
      expect(style!.fontFamily, 'Source Serif 4');
    }
    for (final style in [text.titleMedium, text.bodyLarge, text.bodyMedium, text.labelLarge, text.labelSmall]) {
      expect(style!.fontFamily, isNot('Source Serif 4'));
    }
    expect(text.labelSmall!.color, selahLightTheme().extension<SelahTones>()!.accent);
    late TextStyle quote, reading;
    await tester.pumpWidget(
      MaterialApp(
        theme: selahLightTheme(),
        home: Builder(
          builder: (context) {
            quote = serifQuote(context);
            reading = serifReading(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(quote.fontFamily, 'Source Serif 4');
    expect(quote.fontStyle, FontStyle.italic);
    expect(reading.fontFamily, 'Source Serif 4');
    expect(reading.fontSize, 18);
  });
}
