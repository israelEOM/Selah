import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../data/providers.dart';
import 'event_labels.dart';

void _openExternally(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

/// A church's upcoming events from its own calendar: the next one first, then the rest. Events open on the
/// church's site.
class EventsPage extends ConsumerWidget {
  const EventsPage({super.key, required this.church, this.open = _openExternally, this.today});

  final Church church;
  final void Function(Uri) open;

  /// Fixes "today" for the day labels; the real date when null.
  final DateTime? today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final events = ref
        .watch(upcomingEventsProvider(church.id))
        .whenData((events) => [...events]..sort((a, b) => a.startsAt.compareTo(b.startsAt)));
    return SelahPage(
      onRefresh: () => ref.refresh(upcomingEventsProvider(church.id).future),
      children: [
        Eyebrow(church.name),
        const SizedBox(height: Space.s),
        Text(l.eventsTitle, style: text.displaySmall),
        const SizedBox(height: Space.xl),
        ...events.when(
          loading: () => [const SkeletonList(rows: 3)],
          error: (_, _) => [Text(l.loadError, style: text.bodyMedium)],
          data: (events) => [
            if (events.isNotEmpty) _NextEvent(event: events.first, today: today ?? DateTime.now(), open: open),
            if (events.length > 1) ...[
              const SizedBox(height: Space.xl),
              Eyebrow(l.eventsLater),
              const SizedBox(height: Space.m),
              for (final event in events.skip(1))
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.s + 2),
                  child: _EventRow(event: event, open: open),
                ),
            ],
          ],
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
          style: text.labelSmall?.copyWith(color: tones.accent, fontWeight: FontWeight.w700)),
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

/// A later event: its date badge, title and time.
class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.open});

  final ChurchEvent event;
  final void Function(Uri) open;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final tones = context.tones;
    final url = event.url;
    final row = Container(
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(color: tones.surface, borderRadius: BorderRadius.circular(Radii.row)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              Text('${event.localStart.day}', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              Text(DateFormat.E(l.localeName).format(event.localStart).replaceAll('.', ''),
                  style: text.labelSmall?.copyWith(color: tones.muted)),
            ]),
          ),
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
    );
    return url == null
        ? row
        : Pressable(borderRadius: BorderRadius.circular(Radii.row), onPressed: () => open(url), child: row);
  }
}
