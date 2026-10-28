import 'package:flutter/material.dart';

import '../theme.dart';

/// Hero tag shared by a study day's card and its page, for the shared-element transition.
Object dayHeroTag(String studyId, int dayNumber) => 'day-hero-$studyId-$dayNumber';

/// A [Hero] for a day's card that keeps its text styled mid-flight (the overlay has no Material above it). Under Reduce
/// Motion the flight is switched off, so the page change falls back to the route's own fade.
class DayHero extends StatelessWidget {
  const DayHero({super.key, required this.tag, required this.child});

  final Object tag;
  final Widget child;

  @override
  Widget build(BuildContext context) => HeroMode(
    enabled: !reduceMotion(context),
    child: Hero(
      tag: tag,
      flightShuttleBuilder: (context, animation, direction, from, to) => Material(
        type: MaterialType.transparency,
        // The two cards differ in height, so let the shuttle overflow its in-between size and clip it.
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: 0,
            maxHeight: double.infinity,
            child: (direction == HeroFlightDirection.push ? to : from).widget,
          ),
        ),
      ),
      child: child,
    ),
  );
}

/// The gradient card with an eyebrow, a title, a serif quote and an optional badge and footer.
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, this.eyebrow, this.eyebrowAccessory, this.title, this.quote, this.badge, this.footer});

  final String? eyebrow;

  /// Sits under the eyebrow (the reader's progress dots).
  final Widget? eyebrowAccessory;
  final String? title;
  final String? quote;

  /// Animates in when it goes from null to a value.
  final String? badge;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final tones = context.tones;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // The hero is dark in both themes: white on the light theme's green, the dark theme's light text on brown.
    final onHero = Theme.of(context).brightness == Brightness.light ? scheme.onPrimary : scheme.onSurface;
    final parts = <Widget>[
      if (eyebrow != null)
        Text(eyebrow!.toUpperCase(), style: text.labelSmall?.copyWith(color: onHero.withValues(alpha: 0.8))),
      ?eyebrowAccessory,
      if (title != null) Text(title!, style: text.headlineSmall?.copyWith(color: onHero)),
      if (quote != null) Text(quote!, style: serifQuote(context).copyWith(color: onHero)),
      ?footer,
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.card),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tones.heroStart, tones.heroEnd],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: reduceMotion(context) ? Duration.zero : Motion.medium,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: Tween(begin: 0.8, end: 1.0).animate(animation), child: child),
            ),
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.centerLeft,
              children: [...previous, ?current],
            ),
            child: badge == null ? const SizedBox(key: ValueKey('no-badge'), width: double.infinity) : _Badge(badge!, onHero),
          ),
          if (badge != null) const SizedBox(height: 14),
          for (var i = 0; i < parts.length; i++) ...[if (i > 0) const SizedBox(height: 12), parts[i]],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color) : super(key: const ValueKey('badge'));

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(shape: const StadiumBorder(), color: color.withValues(alpha: 0.16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
