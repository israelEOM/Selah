import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/progress.dart';
import 'part_style.dart';
import 'part_tick.dart';

/// A row for one part of a day: its icon, title and subtitle, and the tick. Opens the part on tap; the icon hops when
/// the part gets ticked.
class PartRow extends StatelessWidget {
  const PartRow({
    super.key,
    required this.part,
    required this.title,
    this.subtitle,
    required this.ticked,
    required this.onTick,
    required this.onOpen,
  });

  final DayPart part;
  final String title;
  final String? subtitle;
  final bool ticked;
  final VoidCallback onTick;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tone = partTone(context, part);
    final tones = context.tones;
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(Radii.row);
    final ios = uiPlatformOf(context) == UiPlatform.ios;
    final decoration = BoxDecoration(color: tone.tint, borderRadius: radius);
    const padding = EdgeInsets.fromLTRB(14, 12, 8, 12);
    final content = Row(
      children: [
        PartHop(active: ticked, child: PartIcon(part: part)),
        const SizedBox(width: Space.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              if (subtitle != null) Text(subtitle!, style: text.bodyMedium?.copyWith(color: tones.muted)),
            ],
          ),
        ),
        PartTick(key: ValueKey('tick-${part.name}'), part: part, label: title, ticked: ticked, onTap: onTick),
      ],
    );
    return Pressable(
      onPressed: onOpen,
      borderRadius: radius,
      haptic: true,
      child: !ios
          ? Ink(decoration: decoration, padding: padding, child: content)
          : DecoratedBox(
              decoration: decoration,
              child: Padding(padding: padding, child: content),
            ),
    );
  }
}

/// Hops its child (scale 1 to 1.25 to 1, tilting up to 8 degrees) whenever [active] turns true; still with Reduce
/// Motion.
class PartHop extends StatefulWidget {
  const PartHop({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<PartHop> createState() => _PartHopState();
}

class _PartHopState extends State<PartHop> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: Motion.hop, value: 1);
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25).chain(CurveTween(curve: Curves.easeOutBack)), weight: 50),
    TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
  ]).animate(_controller);
  late final Animation<double> _tilt = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0).chain(CurveTween(curve: Curves.easeOutBack)), weight: 50),
    TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
  ]).animate(_controller);

  @override
  void didUpdateWidget(PartHop old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active && !reduceMotion(context)) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) => Transform.rotate(
      angle: _tilt.value * math.pi / 180,
      child: Transform.scale(key: const ValueKey('hop-scale'), scale: _scale.value, child: child),
    ),
  );
}
