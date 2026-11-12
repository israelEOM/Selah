import 'package:flutter/widgets.dart';

import 'platform.dart';
import 'tokens.dart';

/// Crossfades between loading, error and data, so a skeleton gives way to content instead of popping.
///
/// The child is told apart by its runtime type and key: a rebuild of the same kind of child (fresh data, a new day)
/// updates it in place and keeps its state, its scroll position and any Hero in it. With Reduce Motion the swap is
/// instant.
class ContentSwitcher extends StatelessWidget {
  const ContentSwitcher({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final id = ValueKey((child.runtimeType, child.key));
    return AnimatedSwitcher(
      duration: reduceMotion(context) ? Duration.zero : Motion.medium,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      // Top-aligned, and passing the parent's constraints through, so a page or a column keeps its own layout while
      // the two overlap.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        fit: StackFit.passthrough,
        children: [...previous, ?current],
      ),
      transitionBuilder: (shown, animation) => FadeTransition(
        opacity: animation,
        // The outgoing copy leaves its heroes behind, so two never share a tag while they overlap. Always a HeroMode, so
        // turning it off doesn't rebuild the outgoing copy from scratch.
        child: HeroMode(enabled: shown.key == id, child: shown),
      ),
      child: KeyedSubtree(key: id, child: child),
    );
  }
}
