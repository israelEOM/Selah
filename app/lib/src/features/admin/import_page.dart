import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/providers.dart';
import 'admin_gate.dart';

const _languageNames = {'es': 'Español', 'pt': 'Português', 'en': 'English'};

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  final _url = TextEditingController();
  final _start = TextEditingController(text: '00:00:00');
  final _end = TextEditingController();

  Map<String, dynamic>? _video;
  bool _busy = false;
  bool _waitingLong = false;
  String? _error;

  String? _captionCode;
  String _outputLanguage = 'es';
  String _bibleVersion = 'RVR1960';
  bool _customRange = false;
  int _days = 5;

  @override
  void dispose() {
    _url.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _captions => List<Map<String, dynamic>>.from(_video?['languages'] as List? ?? const []);

  Future<void> _findVideo() async {
    final l = AppLocalizations.of(context)!;
    final repo = ref.read(repositoryProvider);
    setState(() {
      _busy = true;
      _waitingLong = false;
      _error = null;
      _video = null;
    });
    try {
      final settings = await ref.read(churchSettingsProvider.future);
      final jobId = await repo.createJob('probe', {'url': _url.text.trim()});
      final started = DateTime.now();
      while (true) {
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        final job = await repo.job(jobId);
        if (job.status == 'failed') {
          setState(() => _error = job.error ?? l.genericError);
          return;
        }
        if (job.status == 'succeeded') {
          final sermonLanguage = settings['default_sermon_language'] as String;
          setState(() {
            _video = job.result;
            // YouTube also lists auto-translated tracks, so prefer the church's language over the first track.
            final match = _captions.where((c) => (c['language_code'] as String).split('-').first == sermonLanguage);
            _captionCode = (match.isNotEmpty ? match.first : _captions.first)['language_code'] as String;
            _outputLanguage = settings['default_output_language'] as String;
            _bibleVersion = settings['default_bible_version_code'] as String;
            _days = settings['default_devotional_days'] as int;
          });
          return;
        }
        if (job.status == 'queued' && DateTime.now().difference(started).inSeconds > 12 && !_waitingLong) {
          setState(() => _waitingLong = true);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = l.genericError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generate() async {
    final l = AppLocalizations.of(context)!;
    final repo = ref.read(repositoryProvider);
    final start = _customRange ? parseClock(_start.text) : 0;
    final end = _customRange && _end.text.trim().isNotEmpty ? parseClock(_end.text) : null;
    final endInvalid = _customRange && _end.text.trim().isNotEmpty && (end == null || end <= (start ?? 0));
    if (start == null || endInvalid) {
      setState(() => _error = l.rangeInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final video = Map<String, dynamic>.from(_video!)..remove('languages');
      final sermonId = await repo.saveSermon({
        ...video,
        'original_language': _captionCode!.split('-').first,
        'start_seconds': start,
        'end_seconds': end,
      });
      await repo.createJob(
        'transcript',
        {
          'language_code': _captionCode,
          'chain': [
            {'step': 'analysis'},
            {
              'step': 'summary',
              'payload': {'output_language': _outputLanguage, 'bible_version_code': _bibleVersion, 'number_of_days': _days},
            },
            {
              'step': 'devotional',
              'payload': {'days': _days},
            },
          ],
        },
        sermonId: sermonId,
      );
      ref.invalidate(sermonsProvider);
      if (mounted) context.go('/admin/sermons/$sermonId');
    } catch (_) {
      if (mounted) setState(() => _error = l.jobAlreadyRunning);
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
    final video = _video;
    return AdminPage(backTo: '/admin', maxWidth: 640, children: [
      Eyebrow(l.importSermon),
      const SizedBox(height: 8),
      Text(l.newSermonTitle, style: text.headlineMedium),
      const SizedBox(height: 24),
      TextField(
        controller: _url,
        enabled: !_busy,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(labelText: l.youtubeUrl, hintText: 'https://www.youtube.com/watch?v=…'),
        onSubmitted: (_) => _findVideo(),
      ),
      const SizedBox(height: 14),
      if (video == null)
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: _busy ? null : _findVideo,
            child: Text(_busy ? l.searchingVideo : l.findVideo),
          ),
        ),
      if (_waitingLong && video == null) ...[
        const SizedBox(height: 12),
        Text(l.workerHint, style: text.bodyMedium),
      ],
      if (video != null) ...[
        Card(
          clipBehavior: Clip.antiAlias,
          child: Row(children: [
            Image.network(video['thumbnail_url'] as String,
                width: 132, height: 88, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 132)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(video['title'] as String? ?? '', style: text.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text(video['channel'] as String? ?? '', style: text.bodyMedium),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 22),
        DropdownButtonFormField<String>(
          initialValue: _captionCode,
          decoration: InputDecoration(labelText: l.captionLanguage),
          items: [
            for (final c in _captions)
              DropdownMenuItem(
                value: c['language_code'] as String,
                child: Text('${c['language']}'.replaceAll('(auto-generated)', '(${l.autoGenerated})')),
              ),
          ],
          onChanged: (v) => setState(() => _captionCode = v),
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
            for (final v in versions) DropdownMenuItem(value: v['code'] as String, child: Text('${v['name']} (${v['code']})')),
          ],
          onChanged: (v) => setState(() => _bibleVersion = v!),
        ),
        const SizedBox(height: 22),
        Text(l.sermonRange, style: text.titleLarge),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(l.fullVideo)),
            ButtonSegment(value: true, label: Text(l.customRange)),
          ],
          selected: {_customRange},
          onSelectionChanged: (s) => setState(() => _customRange = s.first),
        ),
        const SizedBox(height: 10),
        if (!_customRange)
          Text(l.fullVideoHint, style: text.bodyMedium)
        else
          Row(children: [
            Expanded(child: TextField(controller: _start, decoration: InputDecoration(labelText: l.rangeStart))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _end, decoration: InputDecoration(labelText: l.rangeEnd))),
          ]),
        const SizedBox(height: 22),
        Text(l.devotionalLength, style: text.titleLarge),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: [for (final d in const [1, 3, 5, 7]) ButtonSegment(value: d, label: Text(l.daysShort(d)))],
          selected: {_days},
          onSelectionChanged: (s) => setState(() => _days = s.first),
        ),
        const SizedBox(height: 28),
        FilledButton(onPressed: _busy || _captionCode == null ? null : _generate, child: Text(l.generateStudy)),
      ],
      if (_error != null) ...[
        const SizedBox(height: 14),
        Text(_error!, style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
      ],
    ]);
  }
}
