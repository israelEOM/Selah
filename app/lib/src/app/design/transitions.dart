import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'platform.dart';

/// Runs [inner], or a plain fade when the user has Reduce Motion on.
class ReduceMotionPageTransitionsBuilder extends PageTransitionsBuilder {
  const ReduceMotionPageTransitionsBuilder(this.inner);

  final PageTransitionsBuilder inner;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (reduceMotion(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    return inner.buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// Slide on iOS, predictive back on Android, fade-forwards on web.
PageTransitionsTheme selahPageTransitions() {
  const cupertino = ReduceMotionPageTransitionsBuilder(
    CupertinoPageTransitionsBuilder(),
  );
  if (kIsWeb) {
    const web = ReduceMotionPageTransitionsBuilder(
      FadeForwardsPageTransitionsBuilder(),
    );
    return PageTransitionsTheme(
      builders: {for (final p in TargetPlatform.values) p: web},
    );
  }
  return const PageTransitionsTheme(
    builders: {
      TargetPlatform.iOS: cupertino,
      TargetPlatform.macOS: cupertino,
      TargetPlatform.android: ReduceMotionPageTransitionsBuilder(
        PredictiveBackPageTransitionsBuilder(),
      ),
    },
  );
}
