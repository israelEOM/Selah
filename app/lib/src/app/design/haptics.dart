import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Haptic taps; no-ops on web.
abstract final class SelahHaptics {
  /// Picking a value or switching a segment.
  static Future<void> selection() async {
    if (kIsWeb) return;
    await HapticFeedback.selectionClick();
  }

  /// A light press.
  static Future<void> tick() async {
    if (kIsWeb) return;
    await HapticFeedback.lightImpact();
  }

  /// A completed action.
  static Future<void> success() async {
    if (kIsWeb) return;
    await HapticFeedback.mediumImpact();
  }
}
