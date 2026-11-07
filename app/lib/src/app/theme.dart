import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'design/tokens.dart';
import 'design/transitions.dart';

export 'design/adaptive_controls.dart';
export 'design/breakpoints.dart';
export 'design/haptics.dart';
export 'design/hero_card.dart';
export 'design/navigation.dart';
export 'design/platform.dart';
export 'design/pressable.dart';
export 'design/selah_row.dart';
export 'design/selah_page.dart';
export 'design/skeleton.dart';
export 'design/tokens.dart';

const _serif = 'Source Serif 4';
const _serifFallback = ['Georgia', 'serif'];

/// Colors beyond [ColorScheme] that the Today page and rows need.
@immutable
class SelahTones extends ThemeExtension<SelahTones> {
  const SelahTones({
    required this.surface,
    required this.muted,
    required this.accent,
    required this.done,
    required this.today,
    required this.heroStart,
    required this.heroEnd,
  });

  final Color surface;
  final Color muted;
  final Color accent;
  final Color done;
  final Color today;
  final Color heroStart;
  final Color heroEnd;

  @override
  SelahTones copyWith({
    Color? surface,
    Color? muted,
    Color? accent,
    Color? done,
    Color? today,
    Color? heroStart,
    Color? heroEnd,
  }) => SelahTones(
    surface: surface ?? this.surface,
    muted: muted ?? this.muted,
    accent: accent ?? this.accent,
    done: done ?? this.done,
    today: today ?? this.today,
    heroStart: heroStart ?? this.heroStart,
    heroEnd: heroEnd ?? this.heroEnd,
  );

  @override
  SelahTones lerp(ThemeExtension<SelahTones>? other, double t) {
    if (other is! SelahTones) return this;
    return SelahTones(
      surface: Color.lerp(surface, other.surface, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      done: Color.lerp(done, other.done, t)!,
      today: Color.lerp(today, other.today, t)!,
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t)!,
    );
  }
}

extension SelahThemeX on BuildContext {
  SelahTones get tones => Theme.of(this).extension<SelahTones>()!;
}

/// The serif, in italic, for the hero quote.
TextStyle serifQuote(BuildContext context) => TextStyle(
  fontFamily: _serif,
  fontFamilyFallback: _serifFallback,
  fontSize: 22,
  height: 1.35,
  fontStyle: FontStyle.italic,
  color: Theme.of(context).colorScheme.onSurface,
);

/// The serif for long reading text (reflection, application, prayer).
TextStyle serifReading(BuildContext context) => TextStyle(
  fontFamily: _serif,
  fontFamilyFallback: _serifFallback,
  fontSize: 18,
  height: 1.7,
  color: Theme.of(context).colorScheme.onSurface,
);

class _Palette {
  const _Palette({
    required this.brightness,
    required this.background,
    required this.text,
    required this.primary,
    required this.onPrimary,
    required this.tones,
  });

  final Brightness brightness;
  final Color background;
  final Color text;
  final Color primary;
  final Color onPrimary;
  final SelahTones tones;
}

const _light = _Palette(
  brightness: Brightness.light,
  background: Color(0xFFFAF7F2),
  text: Color(0xFF262320),
  primary: Color(0xFF2F5D4A),
  onPrimary: Color(0xFFFAF7F2),
  tones: SelahTones(
    surface: Color(0xFFF1EBE1),
    muted: Color(0xFF6F655A),
    accent: Color(0xFFA65033),
    done: Color(0xFF2F5D4A),
    today: Color(0xFFA65033),
    heroStart: Color(0xFF2F5D4A),
    heroEnd: Color(0xFF244A3B),
  ),
);

const _dark = _Palette(
  brightness: Brightness.dark,
  background: Color(0xFF1E1C1A),
  text: Color(0xFFEDE8E1),
  primary: Color(0xFFA9CDB8),
  onPrimary: Color(0xFF1E1C1A),
  tones: SelahTones(
    surface: Color(0xFF272421),
    muted: Color(0xFF9C948A),
    accent: Color(0xFFE0906E),
    done: Color(0xFFA9CDB8),
    today: Color(0xFFE0906E),
    heroStart: Color(0xFF26332C),
    heroEnd: Color(0xFF1F2A24),
  ),
);

/// Headings are set in the serif.
TextStyle _heading(double size, Color color, {double height = 1.15}) =>
    TextStyle(
      fontFamily: _serif,
      fontFamilyFallback: _serifFallback,
      fontSize: size,
      height: height,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      color: color,
    );

ThemeData _build(_Palette p) {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: p.primary,
        brightness: p.brightness,
      ).copyWith(
        primary: p.primary,
        onPrimary: p.onPrimary,
        secondary: p.tones.accent,
        surface: p.background,
        onSurface: p.text,
        // Every container steps from the page toward the raised surface, so none picks up the seed's green-gray.
        surfaceContainerLowest: p.background,
        surfaceContainerLow: Color.lerp(p.background, p.tones.surface, 0.25),
        surfaceContainer: Color.lerp(p.background, p.tones.surface, 0.5),
        surfaceContainerHigh: Color.lerp(p.background, p.tones.surface, 0.75),
        surfaceContainerHighest: p.tones.surface,
        outline: p.tones.muted,
        outlineVariant: p.tones.muted.withValues(alpha: 0.3),
        inverseSurface: p.text,
        onInverseSurface: p.background,
      );
  return ThemeData(
    brightness: p.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    extensions: [p.tones],
    pageTransitionsTheme: selahPageTransitions(),
    textTheme: TextTheme(
      displaySmall: _heading(40, p.text, height: 1.1),
      headlineMedium: _heading(30, p.text),
      headlineSmall: _heading(24, p.text, height: 1.25),
      titleLarge: _heading(20, p.text, height: 1.3),
      titleMedium: TextStyle(fontSize: 17, height: 1.35, fontWeight: FontWeight.w600, color: p.text),
      bodyLarge: TextStyle(fontSize: 17, height: 1.55, color: p.text),
      bodyMedium: TextStyle(fontSize: 15, height: 1.5, color: p.tones.muted),
      bodySmall: TextStyle(fontSize: 13, height: 1.45, color: p.tones.muted),
      labelLarge: TextStyle(fontSize: 15, height: 1.2, fontWeight: FontWeight.w600, color: p.text),
      labelMedium: TextStyle(fontSize: 12, height: 1.3, fontWeight: FontWeight.w600, color: p.text),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: p.tones.accent,
      ),
    ),
    // iOS large and slim titles come from the Cupertino theme, not the Material text theme.
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: p.brightness,
      primaryColor: p.primary,
      textTheme: CupertinoTextThemeData(
        primaryColor: p.primary,
        navLargeTitleTextStyle: _heading(34, p.text, height: 1.15),
        navTitleTextStyle: _heading(17, p.text, height: 1.3),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.tones.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.primary.withValues(alpha: 0.16),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: p.background,
      indicatorColor: p.primary.withValues(alpha: 0.16),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: p.tones.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.row)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.primary,
        side: BorderSide(color: p.primary),
        shape: const StadiumBorder(),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.tones.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.control),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.control),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.control),
        borderSide: BorderSide(color: p.primary, width: 1.5),
      ),
    ),
  );
}

ThemeData selahLightTheme() => _build(_light);

ThemeData selahDarkTheme() => _build(_dark);

/// Small uppercase label used above headings.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall);
}

/// Centres page content and caps its width on large screens.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth = 760});

  final List<Widget> children;
  final double maxWidth;

  /// Scrolls to the screen's bottom edge, under a floating tab bar, with the bottom inset (which includes the bar's
  /// height under the shell) as padding so the last item still clears it.
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, Layout.bottomGap + MediaQuery.paddingOf(context).bottom),
          children: children,
        ),
      ),
    ),
  );
}
