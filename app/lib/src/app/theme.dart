import 'package:flutter/material.dart';

class SelahColors {
  static const ink = Color(0xFF14362B);
  static const cream = Color(0xFFF8F3E8);
  static const gold = Color(0xFFC4A66A);
  static const goldDeep = Color(0xFF8D743E);
  static const sage = Color(0xFFDCE4D8);
}

const _serif = 'Georgia';
const _serifFallback = ['Times New Roman', 'serif'];

TextStyle _heading(double size, {double height = 1.15}) => TextStyle(
      fontFamily: _serif,
      fontFamilyFallback: _serifFallback,
      fontSize: size,
      height: height,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
      color: SelahColors.ink,
    );

ThemeData selahTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: SelahColors.ink).copyWith(
    primary: SelahColors.ink,
    onPrimary: SelahColors.cream,
    secondary: SelahColors.goldDeep,
    surface: SelahColors.cream,
    onSurface: SelahColors.ink,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: SelahColors.cream,
    textTheme: TextTheme(
      displaySmall: _heading(40),
      headlineMedium: _heading(30),
      headlineSmall: _heading(24, height: 1.25),
      titleLarge: _heading(20, height: 1.3),
      bodyLarge: const TextStyle(fontSize: 17, height: 1.6, color: SelahColors.ink),
      bodyMedium: TextStyle(fontSize: 15, height: 1.55, color: SelahColors.ink.withValues(alpha: 0.75)),
      labelSmall: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2, color: SelahColors.goldDeep),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: SelahColors.cream,
      foregroundColor: SelahColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white.withValues(alpha: 0.7),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: SelahColors.ink.withValues(alpha: 0.1)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: SelahColors.ink.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: SelahColors.ink.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: SelahColors.gold, width: 1.5),
      ),
    ),
  );
}

/// Small uppercase gold label used above headings.
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

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 40), children: children),
          ),
        ),
      );
}
