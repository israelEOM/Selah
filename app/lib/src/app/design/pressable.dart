import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme.dart';

/// Wraps a tappable surface with a spring press scale, an Android ripple, an optional haptic tick and double-tap
/// protection. Does not paint a background; give the [child] its own.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onPressed,
    this.borderRadius,
    this.haptic = false,
    this.semanticLabel,
  });

  final Widget child;

  /// Null disables the press.
  final VoidCallback? onPressed;
  final BorderRadius? borderRadius;
  final bool haptic;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with TickerProviderStateMixin {
  late final AnimationController _scale = AnimationController.unbounded(vsync: this, value: 1);

  /// Runs for [Motion.tapDebounce] after each accepted tap; frame-driven so it leaves no timer behind. Preserved so
  /// Reduce Motion (which shortens normal controllers) does not shrink the guard.
  late final AnimationController _lock = AnimationController(
    vsync: this,
    duration: Motion.tapDebounce,
    animationBehavior: AnimationBehavior.preserve,
  );

  @override
  void dispose() {
    _scale.dispose();
    _lock.dispose();
    super.dispose();
  }

  void _springTo(double target) {
    if (reduceMotion(context)) return;
    final sim = SpringSimulation(Motion.press, _scale.value, target, _scale.velocity);
    _scale.animateWith(sim).whenComplete(() {
      // Land exactly on the target instead of within the spring's tolerance.
      if (mounted && !_scale.isAnimating) _scale.value = target;
    });
  }

  void _tap() {
    final onPressed = widget.onPressed;
    if (onPressed == null || _lock.isAnimating) return;
    _lock.forward(from: 0);
    if (widget.haptic) SelahHaptics.tick();
    onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final android = uiPlatformOf(context) == UiPlatform.android;
    final Widget target = android
        ? Material(
            type: MaterialType.transparency,
            child: InkWell(borderRadius: widget.borderRadius, onTap: enabled ? _tap : null, child: widget.child),
          )
        : GestureDetector(behavior: HitTestBehavior.opaque, onTap: enabled ? _tap : null, child: widget.child);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: Listener(
        onPointerDown: enabled ? (_) => _springTo(Motion.pressScale) : null,
        onPointerUp: enabled ? (_) => _springTo(1) : null,
        onPointerCancel: enabled ? (_) => _springTo(1) : null,
        child: AnimatedBuilder(
          animation: _scale,
          child: target,
          builder: (context, child) => Transform.scale(scale: _scale.value, child: child),
        ),
      ),
    );
  }
}
