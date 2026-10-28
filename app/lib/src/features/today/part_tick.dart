import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// The round tick for one part of a day: filled with a check when done, outlined otherwise. Ticking springs the
/// circle in and taps a light haptic.
class PartTick extends StatelessWidget {
  const PartTick({super.key, required this.label, required this.ticked, required this.onTap});

  final String label;
  final bool ticked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tones = context.tones;
    return Semantics(
      button: true,
      checked: ticked,
      label: label,
      child: InkResponse(
        onTap: () {
          SelahHaptics.tick();
          onTap();
        },
        radius: 24,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: SpringIn(
              active: ticked,
              child: AnimatedContainer(
                duration: reduceMotion(context) ? Duration.zero : Motion.short,
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ticked ? tones.done : tones.done.withValues(alpha: 0),
                  border: Border.all(color: ticked ? tones.done : tones.muted, width: 1.5),
                ),
                child: ticked ? Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.onPrimary) : null,
              ),
            ),
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
