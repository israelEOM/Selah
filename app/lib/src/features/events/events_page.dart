import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/design/art.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../data/providers.dart';
import 'event_labels.dart';

void openExternally(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

/// A church's upcoming events from its own calendar: the next one first, then the rest. Events open on the
/// church's site.
class EventsPage extends ConsumerWidget {
  const EventsPage({super.key, required this.church, this.open = openExternally, this.now});

  final Church church;
  final void Function(Uri) open;

  /// Fixes the clock for which events have ended and for the day labels; the real time when null.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final now = this.now ?? DateTime.now();
    // The app can sit in memory for days, so what's stored may have ended since it was read.
    final events = ref.watch(upcomingEventsProvider(church.id)).whenData((events) =>
        events.where((e) => e.endsAt.isAfter(now)).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt)));
    final site = siteLayout(context);
    final loaded = events.when(data: (e) => e, loading: () => null, error: (_, _) => null) ?? const <ChurchEvent>[];
    return SelahPage(
      onRefresh: () => ref.refresh(upcomingEventsProvider(church.id).future),
      wide: site,
      // In the app layout the later events are grouped by day under headings that stay while their group scrolls.
      slivers: site || loaded.length < 2
          ? const []
          : [
              const SliverToBoxAdapter(child: SizedBox(height: Space.l)),
              for (final group in groupEvents(loaded.skip(1), now, l))
                SliverMainAxisGroup(slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _GroupHeading(
                      label: group.label,
                      extent: MediaQuery.textScalerOf(context).scale(14) + Space.l + Space.s,
                      background: Theme.of(context).scaffoldBackgroundColor,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Column(children: [
                      for (final event in group.events)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.s + 2),
                          child: EventRow(event: event, open: open),
                        ),
                    ]),
                  ),
                ]),
            ],
      children: [
        Eyebrow(church.name),
        const SizedBox(height: Space.s),
        Text(l.eventsTitle, style: text.displaySmall),
        const SizedBox(height: Space.xl),
        ContentSwitcher(
          child: events.when(
            loading: () => const SkeletonList(rows: 3),
            error: (_, _) => Text(l.loadError, style: text.bodyMedium),
            data: (events) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (events.isEmpty) ...[
                  const SelahArt(
                    artKey: 'scene-empty-events',
                    fixed: true,
                    seed: 'empty-events',
                    width: double.infinity,
                    height: 180,
                  ),
                  const SizedBox(height: Space.l),
                  Text(l.eventsNone, style: text.bodyLarge),
                ],
                if (events.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: site ? Layout.readingMeasure : double.infinity),
                      child: _NextEvent(event: events.first, today: now, open: open),
                    ),
                  ),
                if (site && events.length > 1) ...[
                  const SizedBox(height: Space.xl),
                  Eyebrow(l.eventsLater),
                  const SizedBox(height: Space.m),
                  CardGrid(
                    minTileWidth: 340,
                    maxColumns: 2,
                    children: [for (final event in events.skip(1)) EventRow(event: event, open: open)],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The hero card for the next event.
class _NextEvent extends StatelessWidget {
  const _NextEvent({required this.event, required this.today, required this.open});

  final ChurchEvent event;
  final DateTime today;
  final void Function(Uri) open;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final tones = context.tones;
    final onHero = Theme.of(context).brightness == Brightness.light
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurface;
    final url = event.url;
    final card = HeroCard(
      eyebrowAccessory: Text(heroDayLabel(event.localStart, today, l).toUpperCase(),
          style: text.labelSmall?.copyWith(color: onHero.withValues(alpha: 0.8))),
      title: event.title,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The day is in the label above, so this line is the time and the place.
          Text(
            [eventTimes(event, l), ?event.location].join(' · '),
            style: text.bodyMedium?.copyWith(color: onHero.withValues(alpha: 0.85)),
          ),
          if (url != null) ...[
            const SizedBox(height: Space.m),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: onHero, foregroundColor: tones.heroStart),
              onPressed: () => open(url),
              child: Text(l.eventsDetails),
            ),
          ],
        ],
      ),
    );
    return url == null
        ? card
        : Pressable(borderRadius: BorderRadius.circular(Radii.card), onPressed: () => open(url), child: card);
  }
}

/// Events in runs that share a heading: Today, Tomorrow, a weekday within the week, then Later. [events] are in
/// date order.
List<({String label, List<ChurchEvent> events})> groupEvents(Iterable<ChurchEvent> events, DateTime now, AppLocalizations l) {
  final today = DateTime(now.year, now.month, now.day);
  String label(ChurchEvent e) {
    final start = e.localStart;
    final days = DateTime(start.year, start.month, start.day).difference(today).inDays;
    if (days <= 0) return l.eventsToday;
    if (days == 1) return l.eventsTomorrow;
    if (days <= 6) {
      final weekday = DateFormat.EEEE(l.localeName).format(start);
      return weekday[0].toUpperCase() + weekday.substring(1);
    }
    return l.eventsLater;
  }

  final groups = <({String label, List<ChurchEvent> events})>[];
  for (final event in events) {
    final name = label(event);
    if (groups.isNotEmpty && groups.last.label == name) {
      groups.last.events.add(event);
    } else {
      groups.add((label: name, events: [event]));
    }
  }
  return groups;
}

/// A group's heading, pinned to the top while the group's events scroll under it.
class _GroupHeading extends SliverPersistentHeaderDelegate {
  _GroupHeading({required this.label, required this.extent, required this.background});

  final String label;
  final double extent;
  final Color background;

  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Semantics(
        header: true,
        child: ColoredBox(
          color: background,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Eyebrow(label),
          ),
        ),
      );

  @override
  bool shouldRebuild(_GroupHeading old) => label != old.label || extent != old.extent || background != old.background;
}

/// One event as a row: a date tile, the title and the times. Tapping opens its details in a sheet.
class EventRow extends StatelessWidget {
  const EventRow({super.key, required this.event, this.open = openExternally});

  final ChurchEvent event;
  final void Function(Uri) open;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final tones = context.tones;
    return Pressable(
      borderRadius: BorderRadius.circular(Radii.row),
      onPressed: () => showEventSheet(context, event, open),
      child: Container(
        padding: const EdgeInsets.all(Space.m),
        decoration: BoxDecoration(color: tones.surface, borderRadius: BorderRadius.circular(Radii.row)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateTile(date: event.localStart),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(eventTimes(event, l), style: text.bodyMedium?.copyWith(color: tones.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The month in terracotta over the day number in the serif. The number counts up from 0 when the tile first
/// appears; it is shown at once with Reduce Motion.
class _DateTile extends StatelessWidget {
  const _DateTile({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final reduce = reduceMotion(context);
    return Container(
      key: const ValueKey('event-date-tile'),
      width: 44,
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              DateFormat.MMM(l.localeName).format(date).replaceAll('.', ''),
              style: text.labelSmall?.copyWith(color: context.tones.accent, fontWeight: FontWeight.w700),
            ),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: reduce ? date.day : 0, end: date.day),
              duration: reduce ? Duration.zero : Motion.long,
              curve: Curves.easeOutCubic,
              builder: (context, day, _) => Text(
                '$day',
                style: serifReading(context).copyWith(fontSize: 20, height: 1.1, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// An event's details in a bottom sheet: when, where, and its page on the church's site when it has one.
Future<void> showEventSheet(BuildContext context, ChurchEvent event, void Function(Uri) open) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) {
      final l = AppLocalizations.of(sheet)!;
      final text = Theme.of(sheet).textTheme;
      final tones = sheet.tones;
      final url = event.url;
      Widget line(IconData icon, String value) => Padding(
            padding: const EdgeInsets.only(top: Space.s),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, size: 20, color: tones.muted),
              const SizedBox(width: Space.s),
              Expanded(child: Text(value, style: text.bodyLarge)),
            ]),
          );
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(event.title, style: text.headlineSmall),
              const SizedBox(height: Space.s),
              line(Icons.schedule, '${shortDate(event.localStart, l)} · ${eventTimes(event, l)}'),
              if (event.location case final location?) line(Icons.place_outlined, location),
              if (url != null) ...[
                const SizedBox(height: Space.xl),
                FilledButton(
                  onPressed: () {
                    Navigator.of(sheet).pop();
                    open(url);
                  },
                  child: Text(l.eventsDetails),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
