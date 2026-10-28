import 'package:flutter/physics.dart';

/// Spacing scale.
abstract final class Space {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class Radii {
  static const row = 20.0;
  static const card = 28.0;
}

abstract final class Motion {
  static const short = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 280);
  static const long = Duration(milliseconds: 420);
  static const staggerStep = Duration(milliseconds: 40);
  static const tapDebounce = Duration(milliseconds: 400);
  static const pressScale = 0.97;
  static const press = SpringDescription(mass: 1, stiffness: 500, damping: 28);
}
