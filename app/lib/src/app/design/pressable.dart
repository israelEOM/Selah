import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme.dart';

/// Wraps a tappable surface with a spring press scale, an Android and web ripple, keyboard activation, an optional
/// haptic tick and double-tap protection. Does not paint a background; give the [child] its own.
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

  /// Where the finger went down, so a press that turns into a scroll or drag can let go of the shrink.
  Offset? _downAt;

  void _down(PointerDownEvent event) {
    _downAt = event.position;
    _springTo(Motion.pressScale);
  }

  void _move(PointerMoveEvent event) {
    final downAt = _downAt;
    // Past touch slop a drag wins the gesture arena, so this is no longer a press.
    if (downAt == null || (event.position - downAt).distance <= kTouchSlop) return;
    _downAt = null;
    _springTo(1);
  }

  void _release(PointerEvent _) {
    _downAt = null;
    _springTo(1);
  }

  late final Map<Type, Action<Intent>> _actions = {
    ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _tap()),
    ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) => _tap()),
  };

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final ios = uiPlatformOf(context) == UiPlatform.ios;
    // Android and web get the ink ripple; iOS a plain press. Both can be focused and activated from a keyboard.
    final Widget target = ios
        ? FocusableActionDetector(
            enabled: enabled,
            actions: _actions,
            mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: enabled ? _tap : null, child: widget.child),
          )
        : Material(
            type: MaterialType.transparency,
            child: InkWell(borderRadius: widget.borderRadius, onTap: enabled ? _tap : null, child: widget.child),
          );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: Listener(
        onPointerDown: enabled ? _down : null,
        onPointerMove: enabled ? _move : null,
        onPointerUp: enabled ? _release : null,
        onPointerCancel: enabled ? _release : null,
        child: AnimatedBuilder(
          animation: _scale,
          child: target,
          builder: (context, child) => Transform.scale(scale: _scale.value, child: child),
        ),
      ),
    );
  }
}
