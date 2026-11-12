import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Repeats [builder] with a 0..1 value over [duration]; holds still at [still] with Reduce Motion.
class _Loop extends StatefulWidget {
  const _Loop({required this.duration, required this.reverse, required this.still, required this.builder});

  final Duration duration;
  final bool reverse;
  final double still;
  final Widget Function(BuildContext context, double t) builder;

  @override
  State<_Loop> createState() => _LoopState();
}

class _LoopState extends State<_Loop> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: widget.reverse);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return widget.builder(context, widget.still);
    return AnimatedBuilder(animation: _controller, builder: (context, _) => widget.builder(context, _controller.value));
  }
}

/// A slow band of full opacity sweeping across [child], on repeat; [child] as it is with Reduce Motion. The band only
/// sets the alpha (`dstIn`), so the child keeps its own colours.
class Shimmer extends StatelessWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    return _Loop(
      duration: Motion.shimmer,
      reverse: false,
      still: 0,
      builder: (context, t) => ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment(-1.5 + 3 * t, 0),
          end: Alignment(-0.5 + 3 * t, 0),
          colors: const [Color(0x8C000000), Color(0xFF000000), Color(0x8C000000)],
        ).createShader(bounds),
        child: child,
      ),
    );
  }
}

/// Fades [child] between 0.6 and full opacity, slowly, on repeat; steady with Reduce Motion.
class Breathe extends StatelessWidget {
  const Breathe({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => _Loop(
        duration: Motion.breathe,
        reverse: true,
        still: 1,
        builder: (context, t) => Opacity(opacity: Motion.breatheLow + (1 - Motion.breatheLow) * t, child: child),
      );
}
