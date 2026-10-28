import 'package:flutter/material.dart';

import 'design/transitions.dart';

export 'design/haptics.dart';
export 'design/hero_card.dart';
export 'design/navigation.dart';
export 'design/platform.dart';
export 'design/pressable.dart';
export 'design/selah_row.dart';
export 'design/skeleton.dart';
export 'design/tokens.dart';

const _serif = 'Georgia';
const _serifFallback = ['Times New Roman', 'serif'];

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

/// Georgia for the hero quote.
TextStyle serifQuote(BuildContext context) => TextStyle(
  fontFamily: _serif,
  fontFamilyFallback: _serifFallback,
  fontSize: 22,
  height: 1.35,
  fontStyle: FontStyle.italic,
  color: Theme.of(context).colorScheme.onSurface,
);

/// Georgia for long reading text (reflection, application, prayer).
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
  background: Color(0xFFFFFFFF),
  text: Color(0xFF0E2341),
  primary: Color(0xFF2E4A38),
  onPrimary: Color(0xFFFFFFFF),
  tones: SelahTones(
    surface: Color(0xFFEDEFF3),
    muted: Color(0xFF697380),
    accent: Color(0xFFF15A24),
    done: Color(0xFF2E4A38),
    today: Color(0xFFF15A24),
    heroStart: Color(0xFF2E4A38),
    heroEnd: Color(0xFF1D3326),
  ),
);

const _dark = _Palette(
  brightness: Brightness.dark,
  background: Color(0xFF0B0B0C),
  text: Color(0xFFF2F2F2),
  primary: Color(0xFF5BC49A),
  onPrimary: Color(0xFF0B0B0C),
  tones: SelahTones(
    surface: Color(0xFF1A1A1C),
    muted: Color(0xFF8B8B90),
    accent: Color(0xFF5BC49A),
    done: Color(0xFFC9A46A),
    today: Color(0xFFF2F2F2),
    heroStart: Color(0xFF5A4630),
    heroEnd: Color(0xFF2A2016),
  ),
);

TextStyle _heading(double size, Color color, {double height = 1.15}) =>
    TextStyle(
      fontSize: size,
      height: height,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
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
        surfaceContainerHighest: p.tones.surface,
      );
  return ThemeData(
    brightness: p.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    extensions: [p.tones],
    pageTransitionsTheme: selahPageTransitions(),
    textTheme: TextTheme(
      displaySmall: _heading(40, p.text),
      headlineMedium: _heading(30, p.text),
      headlineSmall: _heading(24, p.text, height: 1.25),
      titleLarge: _heading(20, p.text, height: 1.3),
      bodyLarge: TextStyle(fontSize: 17, height: 1.6, color: p.text),
      bodyMedium: TextStyle(
        fontSize: 15,
        height: 1.55,
        color: p.text.withValues(alpha: 0.75),
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        color: p.primary,
      ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.tones.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
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
          padding: EdgeInsets.fromLTRB(20, 16, 20, 40 + MediaQuery.paddingOf(context).bottom),
          children: children,
        ),
      ),
    ),
  );
}
