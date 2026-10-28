import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Slide on iOS, predictive back on Android, fade-forwards on web. Kept under
/// Reduce Motion too, since these builders also carry the back gestures.
PageTransitionsTheme selahPageTransitions() {
  if (kIsWeb) {
    const web = FadeForwardsPageTransitionsBuilder();
    return PageTransitionsTheme(
      builders: {for (final p in TargetPlatform.values) p: web},
    );
  }
  return const PageTransitionsTheme(
    builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
    },
  );
}
