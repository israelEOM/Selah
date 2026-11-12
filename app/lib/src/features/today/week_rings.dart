import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../data/progress.dart';
import 'part_style.dart';

const _stroke = 3.2;
const _gap = 0.30; // radians between arcs

/// Paints one of a ring's three arcs: a pale track, and over it the part's colour swept to [progress].
/// Arcs start at 12 o'clock in the order reading, reflection, prayer.
class RingArcPainter extends CustomPainter {
  const RingArcPainter({
    required this.part,
    required this.color,
    required this.track,
    required this.progress,
  });

  final DayPart part;
  final Color color;
  final Color track;

  /// How much of the arc is coloured, 0 to 1. Can overshoot 1 while the arc springs in; it is clamped when drawn.
  final double progress;

  bool get ticked => progress > 0;

  @override
  void paint(Canvas canvas, Size size) {
    const third = 2 * math.pi / 3;
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    final start =
        -math.pi / 2 + DayPart.values.indexOf(part) * third + _gap / 2;
    const sweep = third - _gap;
    Paint paint(Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _stroke
      ..color = c;
    canvas.drawArc(rect, start, sweep, false, paint(track));
    final p = progress.clamp(0.0, 1.0);
    if (p > 0) canvas.drawArc(rect, start, sweep * p, false, paint(color));
  }

  @override
  bool shouldRepaint(RingArcPainter old) =>
      old.part != part ||
      old.color != color ||
      old.track != track ||
      old.progress != progress;
}

/// A day as three arcs, one per part, each in its part's colour once ticked. A finished day becomes a filled
/// check circle instead, which springs in when the day finishes while it is on screen. [label] (the date number)
/// sits inside.
class PartRing extends StatefulWidget {
  const PartRing({
    super.key,
    required this.parts,
    required this.complete,
    this.label,
    this.size = 30,
    this.today = false,
    this.onHero = false,
  });

  final Set<DayPart> parts;
  final bool complete;
  final String? label;
  final double size;
  final bool today;

  /// Drawn on the green hero card, where green marks vanish: the reading arc and the finished disc take the hero's
  /// text colour, the other arcs are lightened towards it, and the track is a faint wash of it.
  final bool onHero;

  @override
  State<PartRing> createState() => _PartRingState();
}

class _PartRingState extends State<PartRing> {
  /// Whether the day finished while this ring was on screen; only then does the disc spring in.
  bool _finishedHere = false;

  @override
  void didUpdateWidget(PartRing old) {
    super.didUpdateWidget(old);
    if (widget.complete && !old.complete) _finishedHere = true;
  }

  @override
  Widget build(BuildContext context) {
    final PartRing(:parts, :complete, :label, :size, :today, :onHero) = widget;
    final tones = context.tones;
    final reduce = reduceMotion(context);
    final on = heroForeground(context);
    final track = onHero ? on.withValues(alpha: 0.25) : Color.lerp(tones.surface, Colors.black, 0.08)!;
    final done = onHero ? on : tones.done;
    final onDone = onHero ? tones.heroStart : Theme.of(context).colorScheme.onPrimary;
    Color arc(DayPart part) {
      final colour = partTone(context, part).color;
      if (!onHero) return colour;
      return part == DayPart.reading ? on : Color.lerp(colour, on, 0.5)!;
    }
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final part in DayPart.values)
            TweenAnimationBuilder<double>(
              tween: Tween(end: parts.contains(part) ? 1 : 0),
              duration: reduce ? Duration.zero : Motion.medium,
              curve: Curves.easeOutBack,
              builder: (context, value, _) => CustomPaint(
                size: Size.square(size),
                painter: RingArcPainter(
                  part: part,
                  color: arc(part),
                  track: track,
                  progress: value,
                ),
              ),
            ),
          if (label != null && !complete)
            ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.all(_stroke + 1),
                child: FittedBox(
                  child: Text(
                    label,
                    textScaler: TextScaler.noScaling,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: today ? tones.today : tones.muted,
                      fontWeight: today ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          if (complete)
            _Disc(
              key: const ValueKey('ring-disc'),
              animate: _finishedHere && !reduce,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done,
                ),
                child: Icon(Icons.check, size: size * 0.6, color: onDone),
              ),
            ),
        ],
      ),
    );
  }
}

/// A finished day's disc: springs up from 80% and fades in when [animate], or is simply there.
class _Disc extends StatefulWidget {
  const _Disc({super.key, required this.animate, required this.child});

  final bool animate;
  final Widget child;

  @override
  State<_Disc> createState() => _DiscState();
}

class _DiscState extends State<_Disc> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: Motion.medium, value: widget.animate ? 0 : 1);
  late final Animation<double> _scale =
      Tween(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _controller,
        child: ScaleTransition(scale: _scale, child: widget.child),
      );
}

/// Monday to Sunday of [now]'s week: the weekday initial above a [PartRing]. The selected day sits on a pill;
/// days after [now] are faded and can't be picked.
class WeekRings extends StatelessWidget {
  const WeekRings({
    super.key,
    required this.ticks,
    required this.now,
    required this.selected,
    required this.onSelect,
  });

  final Map<String, DateTicks> ticks;
  final DateTime now;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!.localeName;
    final tones = context.tones;
    final today = DateTime(now.year, now.month, now.day);
    final monday = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1),
    );
    return Row(
      key: const ValueKey('week'),
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: _buildDay(
              context,
              locale,
              tones,
              DateTime(monday.year, monday.month, monday.day + i),
              i,
              today,
            ),
          ),
      ],
    );
  }

  Widget _buildDay(
    BuildContext context,
    String locale,
    SelahTones tones,
    DateTime date,
    int i,
    DateTime today,
  ) {
    final key = localDate(date);
    final future = date.isAfter(today);
    final isSelected = key == selected;
    final t = ticks[key];
    final l = AppLocalizations.of(context)!;
    final state = [
      if (date == today) l.weekStateToday,
      if (t?.complete ?? false)
        l.weekStateDone
      else if ((t?.parts.length ?? 0) > 0)
        l.weekStateParts(t!.parts.length),
    ];
    final name = l.weekDaySemantics(
      DateFormat.EEEE(locale).format(date),
      state.isEmpty ? l.weekStateNone : state.join(', '),
    );
    void select() {
      if (isSelected) return;
      SelahHaptics.selection();
      onSelect(key);
    }

    final column = Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? tones.surface : null,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat.E(locale).format(date).substring(0, 1).toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: tones.muted),
          ),
          const SizedBox(height: 6),
          PartRing(
            parts: t?.parts ?? const {},
            complete: t?.complete ?? false,
            label: '${date.day}',
            today: date == today,
          ),
        ],
      ),
    );
    return Semantics(
      key: ValueKey('week-$i'),
      button: !future,
      selected: isSelected,
      enabled: !future,
      label: name,
      onTap: future ? null : select,
      excludeSemantics: true,
      child: Opacity(
        opacity: future ? 0.4 : 1,
        child: IgnorePointer(
          ignoring: future,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: select,
            child: column,
          ),
        ),
      ),
    );
  }
}
