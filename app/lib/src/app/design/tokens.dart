import 'package:flutter/material.dart';

/// Spacing scale.
abstract final class Space {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const section = 40.0;
  static const xxxl = 48.0;
}

abstract final class Radii {
  static const row = 12.0;
  static const card = 16.0;

  /// Inputs and small buttons.
  static const control = 10.0;

  /// The floating tab bar's capsule.
  static const bar = 28.0;

  /// Fully rounded pills and chips.
  static const chip = 999.0;
}

/// Shadows for floating elements. Dark mode relies on lighter surfaces instead.
abstract final class Elevation {
  static List<BoxShadow> raised(Brightness brightness) => [
    BoxShadow(
      color: const Color(0xFF262320).withValues(alpha: brightness == Brightness.light ? 0.08 : 0),
      blurRadius: 24,
      offset: const Offset(0, 6),
    ),
  ];
}

/// Content widths.
abstract final class Layout {
  /// The widest the desktop content area gets.
  static const maxContent = 1200.0;

  /// A comfortable line length for long reading text.
  static const readingMeasure = 680.0;

  /// Forms never stretch wider than this.
  static const formWidth = 440.0;

  /// Space between the last item on a page and the tab bar or the bottom edge.
  static const bottomGap = Space.l;
}

abstract final class Motion {
  static const short = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 280);
  static const long = Duration(milliseconds: 420);
  static const hop = Duration(milliseconds: 600);
  static const ripple = Duration(milliseconds: 600);
  static const staggerStep = Duration(milliseconds: 40);

  /// Admin: the Generando chip's slow sweep, and the running step's slow breathing (opacity 0.6 to 1 and back).
  static const shimmer = Duration(milliseconds: 1600);
  static const breathe = Duration(milliseconds: 1400);
  static const breatheLow = 0.6;

  /// A scene settling in: the fade and the rise, and how far it rises.
  static const sceneIn = Duration(milliseconds: 600);
  static const sceneRise = 12.0;

  /// The sign-in scene's slow parallax: one full loop, and how far it drifts either way.
  static const drift = Duration(seconds: 20);
  static const driftDistance = 6.0;

  /// A refused sign-in shaking the fields.
  static const shake = Duration(milliseconds: 400);
  static const shakeDistance = 8.0;
  static const shakeOscillations = 3;

  /// Moment A: the light rising in the hero card, and the finish line's wait and rise.
  static const glow = Duration(milliseconds: 1800);
  static const finishDelay = Duration(milliseconds: 700);
  static const finishRise = Duration(milliseconds: 1000);

  /// Today's content sliding between days of the week, and how far it travels.
  static const daySwitch = Duration(milliseconds: 250);
  static const daySwitchShift = 24.0;

  /// The reader's tick bar giving way to the "Day complete" pill.
  static const dockSwap = Duration(milliseconds: 600);

  static const tapDebounce = Duration(milliseconds: 400);
  static const pressScale = 0.97;
  static const press = SpringDescription(mass: 1, stiffness: 500, damping: 28);
}
