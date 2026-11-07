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
      expect(contrast(const Color(0xFFF5F0E6), tones.heroStart), greaterThanOrEqualTo(4.5)); // text on hero
      expect(contrast(const Color(0xFFF5F0E6), tones.heroEnd), greaterThanOrEqualTo(4.5));
    });

    test('$name background is neither pure white nor pure black', () {
      expect(theme.scaffoldBackgroundColor, isNot(const Color(0xFFFFFFFF)));
      expect(theme.scaffoldBackgroundColor, isNot(const Color(0xFF000000)));
    });
  }
}
