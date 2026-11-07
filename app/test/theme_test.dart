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
