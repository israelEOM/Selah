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
            child: ((direction == HeroFlightDirection.push ? to : from).widget as Hero).child,
          ),
        ),
      ),
      child: child,
    ),
  );
}

/// The colour of text on the hero card: white on the light theme's green, the dark theme's light text on brown.
Color heroForeground(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return Theme.of(context).brightness == Brightness.light ? scheme.onPrimary : scheme.onSurface;
}

/// The gradient card with an eyebrow, a title, a serif quote and an optional badge and footer. A finished day's card
/// holds a soft light ([glow]), and [art] sits round in the bottom-right corner.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    this.eyebrow,
    this.eyebrowAccessory,
    this.title,
    this.quote,
    this.badge,
    this.footer,
    this.glow = false,
    this.animateGlow = false,
    this.art,
  });

  final String? eyebrow;

  /// Sits under the eyebrow, or stands in for it (the reader's "Day N of M" with the day's ring).
  final Widget? eyebrowAccessory;
  final String? title;
  final String? quote;

  /// Animates in when it goes from null to a value.
  final String? badge;
  final Widget? footer;

  /// A light rising from the bottom of the card: the finished day's rest state.
  final bool glow;

  /// Fades the [glow] in over [Motion.glow] when it first shows (moment A), instead of showing it as-is. Turning this
  /// off mid-way lets the fade finish.
  final bool animateGlow;

  /// An illustration, round, in the bottom-right corner.
  final Widget? art;

  /// The art's visible width (100 px, 14 px of it past the edge) less the card's 22 px padding.
  static const _artClearance = 100.0 - 14 - 22;

  @override
  Widget build(BuildContext context) {
    final tones = context.tones;
    final text = Theme.of(context).textTheme;
    final onHero = heroForeground(context);
    // With art, the title and quote stop short of its visible part, so the round corner never covers them.
    Widget clear(Widget text) =>
        art == null ? text : Padding(padding: const EdgeInsets.only(right: _artClearance), child: text);
    final parts = <Widget>[
      if (eyebrow != null)
        Text(eyebrow!.toUpperCase(), style: text.labelSmall?.copyWith(color: onHero.withValues(alpha: 0.8))),
      ?eyebrowAccessory,
      if (title != null) clear(Text(title!, style: text.headlineSmall?.copyWith(color: onHero))),
      if (quote != null) clear(Text(quote!, style: serifQuote(context).copyWith(color: onHero))),
      ?footer,
    ];
    final content = Padding(
      padding: const EdgeInsets.all(22),
      child: SizedBox(
        width: double.infinity,
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
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.card),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tones.heroStart, tones.heroEnd],
          ),
        ),
        child: Stack(
          children: [
            if (glow) Positioned.fill(child: _Glow(animate: animateGlow && !reduceMotion(context))),
            if (art != null)
              Positioned(
                right: -14,
                bottom: -18,
                child: ExcludeSemantics(
                  child: Opacity(opacity: 0.85, child: ClipOval(child: SizedBox.square(dimension: 100, child: art))),
                ),
              ),
            content,
          ],
        ),
      ),
    );
  }
}

/// The light of moment A: a pale radial highlight from the bottom centre, gone by 65% of the way out.
class _Glow extends StatelessWidget {
  const _Glow({required this.animate});

  final bool animate;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    // Only the first build's tween counts: the end never changes, so a later `animate: false` lets a running fade finish.
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: animate ? 0 : 1, end: 1),
      duration: Motion.glow,
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(key: const ValueKey('hero-glow'), opacity: t, child: child),
      child: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.bottomCenter,
            radius: 1.2,
            colors: [Color.fromRGBO(250, 247, 242, 0.38), Color.fromRGBO(250, 247, 242, 0)],
            stops: [0, 0.65],
          ),
        ),
      ),
    ),
  );
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
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color)),
        ],
      ),
    );
  }
}
