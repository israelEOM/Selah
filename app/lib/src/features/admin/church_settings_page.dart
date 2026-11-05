import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../data/providers.dart';
import 'admin_gate.dart';

const _languageNames = {'es': 'Español', 'pt': 'Português', 'en': 'English'};

/// Zones offered for calendar times that don't name one; the church's own is added when it isn't here.
const _timezones = [
  'Europe/Madrid',
  'Europe/Lisbon',
  'Europe/London',
  'America/Bogota',
  'America/Mexico_City',
  'America/Sao_Paulo',
  'America/New_York',
  'America/Los_Angeles',
];

/// [link] as it is stored: trimmed, webcal as https, null when empty.
String? normalizeCalendarLink(String link) {
  final trimmed = link.trim();
  if (trimmed.isEmpty) return null;
  return trimmed.replaceFirst(RegExp(r'^webcal://', caseSensitive: false), 'https://');
}

/// The owner-facing message for a failed calendar check.
String eventsSyncErrorText(AppLocalizations l, String error) => switch (error) {
      'blocked' => l.eventsBlocked,
      'not_calendar' => l.eventsNotCalendar,
      _ => l.eventsUnreachable,
    };

/// Owner-only: the church's name, the defaults the import page starts from, and its calendar link.
/// The monthly limit is not here; only the platform admin changes it.
class ChurchSettingsPage extends ConsumerStatefulWidget {
  const ChurchSettingsPage({super.key, required this.church});

  final Church church;

  @override
  ConsumerState<ChurchSettingsPage> createState() => _ChurchSettingsPageState();
}

class _ChurchSettingsPageState extends ConsumerState<ChurchSettingsPage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.church.name);
  late String _sermonLanguage = widget.church.defaultSermonLanguage ?? 'es';
  late String _outputLanguage = widget.church.defaultOutputLanguage ?? 'es';
  late String _bibleVersion = widget.church.defaultBibleVersionCode ?? 'RVR1960';
  late int _days = widget.church.defaultDevotionalDays ?? 5;
  late final _calendar = TextEditingController(text: widget.church.eventsCalendarUrl ?? '');
  late String _timezone = widget.church.timezone;
  late String? _savedCalendar = widget.church.eventsCalendarUrl;
  bool _busy = false;
  String? _message;
  bool _failed = false;

  /// What the last check of the calendar found, shown under the link.
  String? _calendarMessage;
  bool _calendarFailed = false;

  @override
  void dispose() {
    _name.dispose();
    _calendar.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final calendar = normalizeCalendarLink(_calendar.text);
    try {
      final repository = ref.read(repositoryProvider);
      await repository.updateChurch(widget.church.id, {
        'name': _name.text.trim(),
        'default_sermon_language': _sermonLanguage,
        'default_output_language': _outputLanguage,
        'default_bible_version_code': _bibleVersion,
        'default_devotional_days': _days,
        'events_calendar_url': calendar,
        'timezone': _timezone,
      });
      // The link is checked on every save, so the owner knows it works before members do, and can confirm a fix
      // (a web admin letting Selah through, a new timezone). It stays saved either way, and the refresh keeps trying.
      final checked = calendar != null ? await repository.syncChurchEvents(widget.church.id) : null;
      _savedCalendar = calendar;
      ref.invalidate(churchProvider(widget.church.slug));
      ref.invalidate(upcomingEventsProvider(widget.church.id));
      if (mounted) {
        setState(() {
          _failed = false;
          _message = l.saved;
          if (calendar == null) {
            _calendarMessage = null;
          } else if (checked != null) {
            final (message, failed) = switch (checked) {
              EventsSynced(:final count) => (l.eventsFound(count), false),
              EventsSyncFailed(:final error) => (eventsSyncErrorText(l, error), true),
            };
            _calendarMessage = message;
            _calendarFailed = failed;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _message = l.genericError;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final versions = (ref.watch(bibleVersionsProvider).value ?? const [])
        .where((v) => v['language'] == _outputLanguage)
        .toList();
    return AdminPage(
      church: widget.church,
      minRole: ChurchRole.owner,
      backTo: '/c/${widget.church.slug}/admin',
      maxWidth: 640,
      children: [
        Eyebrow(l.churchSettings),
        const SizedBox(height: 8),
        Text(widget.church.name, style: text.headlineMedium),
        const SizedBox(height: 24),
        Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: l.churchName),
              validator: (v) {
                final n = (v ?? '').trim().length;
                return n < 2 || n > 80 ? l.churchNameInvalid : null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              initialValue: widget.church.slug,
              readOnly: true,
              enabled: false,
              decoration: InputDecoration(labelText: l.churchLink),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _sermonLanguage,
              decoration: InputDecoration(labelText: l.captionLanguage),
              items: [for (final e in _languageNames.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => setState(() => _sermonLanguage = v!),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _outputLanguage,
              decoration: InputDecoration(labelText: l.outputLanguage),
              items: [for (final e in _languageNames.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => setState(() {
                _outputLanguage = v!;
                final first = (ref.read(bibleVersionsProvider).value ?? const []).where((b) => b['language'] == v);
                if (first.isNotEmpty) _bibleVersion = first.first['code'] as String;
              }),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey(_outputLanguage),
              initialValue: versions.any((v) => v['code'] == _bibleVersion) ? _bibleVersion : null,
              decoration: InputDecoration(labelText: l.bibleVersion),
              items: [
                for (final v in versions)
                  DropdownMenuItem(value: v['code'] as String, child: Text('${v['name']} (${v['code']})')),
              ],
              onChanged: (v) => setState(() => _bibleVersion = v!),
            ),
            const SizedBox(height: 22),
            Text(l.devotionalLength, style: text.titleLarge),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [for (final d in const [1, 3, 5, 7]) ButtonSegment(value: d, label: Text(l.daysShort(d)))],
              selected: {_days},
              onSelectionChanged: (s) => setState(() => _days = s.first),
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: _calendar,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(labelText: l.eventsCalendarLink, helperText: l.eventsCalendarHint,
                  helperMaxLines: 3),
              validator: (v) {
                final link = normalizeCalendarLink(v ?? '');
                if (link == null) return null;
                final uri = Uri.tryParse(link);
                return uri == null || uri.scheme != 'https' || uri.host.isEmpty ? l.eventsCalendarInvalid : null;
              },
            ),
            if (_calendarStatus(l) case (final String status, final bool failed)) ...[
              const SizedBox(height: 8),
              Text(status,
                  style: text.bodySmall?.copyWith(color: failed ? Theme.of(context).colorScheme.error : null)),
            ],
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _timezone,
              decoration: InputDecoration(labelText: l.churchTimezone),
              items: [
                for (final zone in {..._timezones, _timezone}) DropdownMenuItem(value: zone, child: Text(zone)),
              ],
              onChanged: (v) => setState(() => _timezone = v!),
            ),
            const SizedBox(height: 28),
            FilledButton(onPressed: _busy ? null : _save, child: Text(l.save)),
            if (_message != null) ...[
              const SizedBox(height: 14),
              Text(_message!,
                  style: text.bodyMedium?.copyWith(color: _failed ? Theme.of(context).colorScheme.error : null)),
            ],
          ]),
        ),
      ],
    );
  }

  /// This session's check result, else the last refresh or its problem, while there's a link.
  (String, bool)? _calendarStatus(AppLocalizations l) {
    if (_calendarMessage != null) return (_calendarMessage!, _calendarFailed);
    final church = widget.church;
    if (church.eventsCalendarUrl == null || church.eventsCalendarUrl != _savedCalendar) return null;
    if (church.eventsSyncError case final error?) return (eventsSyncErrorText(l, error), true);
    if (church.eventsSyncedAt case final at?) {
      return (l.eventsLastSync(DateFormat.MMMd(l.localeName).add_Hm().format(at.toLocal())), false);
    }
    return null;
  }
}
