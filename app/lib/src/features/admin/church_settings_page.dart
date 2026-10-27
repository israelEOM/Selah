import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../data/providers.dart';
import 'admin_gate.dart';

const _languageNames = {'es': 'Español', 'pt': 'Português', 'en': 'English'};

/// Owner-only: the church's name and the defaults the import page starts from.
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
  bool _busy = false;
  String? _message;
  bool _failed = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(repositoryProvider).updateChurch(widget.church.id, {
        'name': _name.text.trim(),
        'default_sermon_language': _sermonLanguage,
        'default_output_language': _outputLanguage,
        'default_bible_version_code': _bibleVersion,
        'default_devotional_days': _days,
      });
      ref.invalidate(churchProvider(widget.church.slug));
      if (mounted) {
        setState(() {
          _failed = false;
          _message = l.saved;
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
}
