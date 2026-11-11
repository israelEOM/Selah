import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/src/app/theme.dart';

/// WCAG 2.x contrast ratio between two opaque colors.
double contrast(Color a, Color b) {
  double channel(double c) => c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
  double luminance(Color c) => 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  final la = luminance(a), lb = luminance(b);
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  for (final (name, theme) in [('light', selahLightTheme()), ('dark', selahDarkTheme())]) {
    test('$name theme meets WCAG AA', () {
      final s = theme.colorScheme;
      final tones = theme.extension<SelahTones>()!;
      final bg = theme.scaffoldBackgroundColor;
      expect(contrast(s.onSurface, bg), greaterThanOrEqualTo(4.5));
      expect(contrast(s.onSurface, tones.surface), greaterThanOrEqualTo(4.5));
      expect(contrast(tones.muted, bg), greaterThanOrEqualTo(4.5));
      expect(contrast(tones.muted, tones.surface), greaterThanOrEqualTo(4.5));
      expect(contrast(s.primary, bg), greaterThanOrEqualTo(4.5)); // links and labels
      expect(contrast(s.onPrimary, s.primary), greaterThanOrEqualTo(4.5)); // button text
      expect(contrast(tones.accent, bg), greaterThanOrEqualTo(4.5)); // small terracotta labels
      expect(contrast(tones.accent, tones.surface), greaterThanOrEqualTo(4.5)); // eyebrows inside cards
      // HeroCard's text color: onPrimary in light mode, onSurface in dark mode.
      final onHero = theme.brightness == Brightness.light ? s.onPrimary : s.onSurface;
      expect(contrast(onHero, tones.heroStart), greaterThanOrEqualTo(4.5));
      expect(contrast(onHero, tones.heroEnd), greaterThanOrEqualTo(4.5));
      expect(contrast(s.outline, bg), greaterThanOrEqualTo(3)); // borders
      expect(contrast(s.onInverseSurface, s.inverseSurface), greaterThanOrEqualTo(4.5)); // snackbars
    });

    test('$name part colours are legible', () {
      final p = theme.extension<PartPalette>()!;
      final onColor = theme.colorScheme.onPrimary;
      for (final (part, tone) in [('reading', p.reading), ('reflection', p.reflection), ('prayer', p.prayer)]) {
        expect(contrast(tone.color, tone.tint), greaterThanOrEqualTo(3), reason: '$part colour on its tint');
        // The check mark is a graphic, not text, so 3:1 applies (the spec's light reflection colour is 3.55:1).
        expect(contrast(onColor, tone.color), greaterThanOrEqualTo(3), reason: 'check mark on $part colour');
      }
    });

    test('$name surface containers are warm and never darker than the page in dark mode', () {
      final s = theme.colorScheme;
      final bg = theme.scaffoldBackgroundColor;
      for (final c in [s.surfaceContainerLowest, s.surfaceContainerLow, s.surfaceContainer, s.surfaceContainerHigh, s.surfaceContainerHighest]) {
        expect(c.r, greaterThanOrEqualTo(c.b), reason: '$c should lean warm, not green-gray');
        expect(c.r, greaterThanOrEqualTo(c.g), reason: '$c should not lean green');
        if (theme.brightness == Brightness.dark) {
          expect(c.computeLuminance(), greaterThanOrEqualTo(bg.computeLuminance()), reason: '$c is darker than the page');
        }
      }
    });

    test('$name outlined buttons have a green border', () {
      final side = theme.outlinedButtonTheme.style!.side!.resolve({});
      expect(side!.color, theme.colorScheme.primary);
    });

    test('$name background is neither pure white nor pure black', () {
      expect(theme.scaffoldBackgroundColor, isNot(const Color(0xFFFFFFFF)));
      expect(theme.scaffoldBackgroundColor, isNot(const Color(0xFF000000)));
    });
  }
}
