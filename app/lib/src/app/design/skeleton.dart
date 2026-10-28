import 'package:flutter/material.dart';

import '../theme.dart';

/// A shimmering placeholder block; static with Reduce Motion.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, required this.height, this.radius = 12});

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _shimmer.stop();
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.tones.surface;
    final highlight = Color.lerp(base, Theme.of(context).colorScheme.surface, 0.6)!;
    final moving = !reduceMotion(context);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _shimmer,
        builder: (context, _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            color: moving ? null : base,
            gradient: moving
                ? LinearGradient(
                    begin: Alignment(-1.5 + 3 * _shimmer.value, 0),
                    end: Alignment(-0.5 + 3 * _shimmer.value, 0),
                    colors: [base, highlight, base],
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// A loading layout: an optional hero-shaped block followed by [rows] row-shaped blocks.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 4, this.hero = false});

  final int rows;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (hero) ...[const Skeleton(height: 168, radius: Radii.card), const SizedBox(height: Space.l)],
        for (var i = 0; i < rows; i++) ...[
          if (i > 0) const SizedBox(height: Space.m),
          const Skeleton(height: 64, radius: Radii.row),
        ],
      ],
    );
  }
}

/// Fades and slides its child up 12px on first build, staggered by [index]; shown at once with Reduce Motion.
class Entrance extends StatefulWidget {
  const Entrance({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final Duration _delay = Motion.staggerStep * widget.index;
  late final AnimationController _controller = AnimationController(vsync: this, duration: _delay + Motion.medium);
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Interval(_delay.inMicroseconds / _controller.duration!.inMicroseconds, 1, curve: Curves.easeOutCubic),
  );
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
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        child: widget.child,
        builder: (context, child) => Transform.translate(offset: Offset(0, 12 * (1 - _curve.value)), child: child),
      ),
    );
  }
}
