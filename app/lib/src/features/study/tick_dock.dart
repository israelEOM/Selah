import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../data/progress.dart';
import '../today/part_row.dart' show PartHop;
import '../today/part_style.dart';
import '../today/part_tick.dart' show SpringIn;

/// The reader's floating tick bar: one chip per part of the day, always within reach while reading. The [current]
/// part (the section in view) widens to show its name and "Tap to tick"; the others shrink to their icons. Once every
/// part is ticked the bar gives way to a green "Day complete · back to Today" pill, which calls [onComplete].
class TickDock extends StatelessWidget {
  const TickDock({
    super.key,
    required this.parts,
    required this.ticked,
    required this.current,
    required this.onTick,
    required this.onComplete,
  });

  final List<DayPart> parts;
  final Set<DayPart> ticked;
  final DayPart current;
  final ValueChanged<DayPart> onTick;
  final VoidCallback onComplete;

  static const height = 64.0;
  static const sideInset = 12.0;

  /// Above the safe area's bottom edge.
  static const bottomInset = 14.0;

  /// How much further down a page scrolls so its last line clears the bar.
  static const clearance = height + bottomInset;

  static const _currentFlex = 2.8;

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotion(context);
    final done = parts.every(ticked.contains);
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        height: height,
        child: AnimatedSwitcher(
          duration: reduce ? Motion.medium : Motion.dockSwap,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
          transitionBuilder: (child, animation) => reduce
              ? FadeTransition(opacity: animation, child: child)
              : SlideTransition(
                  position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
          child: done ? _CompletePill(key: const ValueKey('dock-complete'), onTap: onComplete) : _bar(context, reduce),
        ),
      ),
    );
  }

  Widget _bar(BuildContext context, bool reduce) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(Radii.chip);
    return DecoratedBox(
      key: const ValueKey('dock-bar'),
      decoration: BoxDecoration(borderRadius: radius, boxShadow: Elevation.raised(theme.brightness)),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: ColoredBox(
            // The web build draws the blur weakly, so the text behind would show through a see-through bar.
            color: theme.scaffoldBackgroundColor.withValues(alpha: kIsWeb ? 0.94 : 0.72),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: TweenAnimationBuilder<_Flexes>(
                tween: _FlexTween(end: _Flexes([for (final p in parts) p == current ? _currentFlex : 1.0])),
                duration: reduce ? Duration.zero : Motion.medium,
                curve: Curves.easeOutBack,
                builder: (context, flex, _) => Row(
                  children: [
                    for (final (i, part) in parts.indexed)
                      Expanded(
                        // Expanded only takes whole numbers, so the animated flex is kept in hundredths.
                        flex: (flex.values[i] * 100).round().clamp(1, 1000),
                        child: _Chip(
                          key: ValueKey('dock-${part.name}'),
                          part: part,
                          ticked: ticked.contains(part),
                          current: part == current,
                          onTap: () => onTick(part),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The chips' flex values, equal by value so a rebuild with the same current part doesn't restart the animation.
@immutable
class _Flexes {
  const _Flexes(this.values);

  final List<double> values;

  @override
  bool operator ==(Object other) => other is _Flexes && listEquals(other.values, values);

  @override
  int get hashCode => Object.hashAll(values);
}

/// Lerps each chip's flex; a list of another length (a different day) jumps straight to the end.
class _FlexTween extends Tween<_Flexes> {
  _FlexTween({required _Flexes super.end});

  @override
  _Flexes lerp(double t) {
    final from = begin?.values, to = end!.values;
    if (from == null || from.length != to.length) return end!;
    return _Flexes([for (var i = 0; i < to.length; i++) lerpDouble(from[i], to[i], t)!]);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.part, required this.ticked, required this.current, required this.onTap});

  final DayPart part;
  final bool ticked;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tone = partTone(context, part);
    final reduce = reduceMotion(context);
    final radius = BorderRadius.circular(Radii.chip);
    final icon = Stack(
      clipBehavior: Clip.none,
      children: [
        PartHop(
          active: ticked,
          child: PartIcon(part: part, size: 36),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: AnimatedOpacity(
            opacity: ticked ? 1 : 0,
            duration: reduce ? Duration.zero : Motion.short,
            child: SpringIn(
              active: ticked,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tone.color,
                  border: Border.all(color: theme.scaffoldBackgroundColor, width: 1.5),
                ),
                child: Icon(Icons.check, size: 11, color: theme.colorScheme.onPrimary),
              ),
            ),
          ),
        ),
      ],
    );
    return Semantics(
      checked: ticked,
      label: partLabel(l, part),
      hint: current ? l.tapToTick : null,
      // Pressable makes it a button, taps the haptic and ignores a second tap within Motion.tapDebounce.
      child: Pressable(
        borderRadius: radius,
        haptic: true,
        onPressed: onTap,
        child: ExcludeSemantics(
          child: AnimatedContainer(
            duration: reduce ? Duration.zero : Motion.medium,
            height: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: current ? tone.tint : tone.tint.withValues(alpha: 0),
              borderRadius: radius,
            ),
            child: Row(
              mainAxisAlignment: current ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                icon,
                if (current) ...[
                  const SizedBox(width: 10),
                  // Scales down rather than overflowing while the chip is still widening, and at large text sizes.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(partLabel(l, part), style: theme.textTheme.titleSmall?.copyWith(color: tone.text)),
                          Text(l.tapToTick, style: theme.textTheme.bodySmall?.copyWith(color: context.tones.muted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The green pill that takes the bar's place once the day is done.
class _CompletePill extends StatelessWidget {
  const _CompletePill({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shape = BorderRadius.circular(Radii.chip);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: shape, boxShadow: Elevation.raised(theme.brightness)),
      child: Material(
        color: scheme.primary,
        borderRadius: shape,
        clipBehavior: Clip.antiAlias,
        child: Pressable(
          borderRadius: shape,
          semanticLabel: l.dayCompleteBackToToday,
          onPressed: onTap,
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.dayCompleteBackToToday,
                        style: theme.textTheme.titleSmall?.copyWith(color: scheme.onPrimary),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 20, color: scheme.onPrimary),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
