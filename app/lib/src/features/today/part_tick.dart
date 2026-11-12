import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/progress.dart';
import 'part_style.dart';

/// The round tick for one part of a day, in that part's colour: filled with a check when done, outlined otherwise.
/// Ticking springs the check in, ripples a ring outwards and taps a light haptic. Reduce Motion skips the ripple.
class PartTick extends StatefulWidget {
  const PartTick({super.key, required this.part, required this.label, required this.ticked, required this.onTap});

  final DayPart part;
  final String label;
  final bool ticked;
  final VoidCallback onTap;

  @override
  State<PartTick> createState() => _PartTickState();
}

class _PartTickState extends State<PartTick> with SingleTickerProviderStateMixin {
  late final AnimationController _ripple = AnimationController(vsync: this, duration: Motion.ripple);

  @override
  void didUpdateWidget(PartTick old) {
    super.didUpdateWidget(old);
    if (widget.ticked && !old.ticked && !reduceMotion(context)) _ripple.forward(from: 0);
  }

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tones = context.tones;
    final color = partTone(context, widget.part).color;
    final ticked = widget.ticked;
    return Semantics(
      button: true,
      checked: ticked,
      label: widget.label,
      child: InkResponse(
        onTap: () {
          SelahHaptics.tick();
          widget.onTap();
        },
        radius: 24,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _ripple,
                builder: (context, _) {
                  if (!_ripple.isAnimating) return const SizedBox.shrink();
                  return IgnorePointer(
                    child: Opacity(
                      key: const ValueKey('tick-ripple'),
                      opacity: 0.7 * (1 - _ripple.value),
                      child: Transform.scale(
                        scale: 1.0 + 0.9 * _ripple.value,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 1.5)),
                        ),
                      ),
                    ),
                  );
                },
              ),
              SpringIn(
                active: ticked,
                child: AnimatedContainer(
                  duration: reduceMotion(context) ? Duration.zero : Motion.short,
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ticked ? color : color.withValues(alpha: 0),
                    border: Border.all(color: ticked ? color : tones.muted, width: 1.5),
                  ),
                  child: ticked ? Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.onPrimary) : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Springs its child from 0.8 to full size whenever [active] turns true; no scale with Reduce Motion.
class SpringIn extends StatefulWidget {
  const SpringIn({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<SpringIn> createState() => _SpringInState();
}

class _SpringInState extends State<SpringIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: Motion.medium, value: 1);
  late final Animation<double> _scale =
      Tween(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  @override
  void didUpdateWidget(SpringIn old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active && !reduceMotion(context)) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(scale: _scale, child: widget.child);
}
