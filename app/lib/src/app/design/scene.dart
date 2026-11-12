import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Fades its child in while it rises [Motion.sceneRise] over [Motion.sceneIn]; already in place with Reduce Motion.
class SceneIn extends StatefulWidget {
  const SceneIn({super.key, required this.child});

  final Widget child;

  @override
  State<SceneIn> createState() => _SceneInState();
}

class _SceneInState extends State<SceneIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: Motion.sceneIn);
  late final Animation<double> _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotion(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _curve,
        child: AnimatedBuilder(
          animation: _curve,
          builder: (context, child) =>
              Transform.translate(offset: Offset(0, (1 - _curve.value) * Motion.sceneRise), child: child),
          child: widget.child,
        ),
      );
}

/// Drifts its child up and down by [Motion.driftDistance] on a [Motion.drift] loop; still with Reduce Motion.
class Drift extends StatefulWidget {
  const Drift({super.key, required this.child});

  final Widget child;

  @override
  State<Drift> createState() => _DriftState();
}

class _DriftState extends State<Drift> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: Motion.drift);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, child) =>
            Transform.translate(offset: Offset(0, sin(_controller.value * 2 * pi) * Motion.driftDistance), child: child),
        child: widget.child,
      );
}

/// Shakes its child sideways ([Motion.shakeOscillations] swings of [Motion.shakeDistance] over [Motion.shake]) each
/// time [trigger] changes. Does nothing with Reduce Motion.
class Shake extends StatefulWidget {
  const Shake({super.key, required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: Motion.shake);

  @override
  void didUpdateWidget(Shake old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && !reduceMotion(context)) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.translate(
          offset: Offset(sin(_controller.value * 2 * pi * Motion.shakeOscillations) * Motion.shakeDistance, 0),
          child: child,
        ),
        child: widget.child,
      );
}
