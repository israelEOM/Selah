import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../data/providers.dart';
import 'admin_gate.dart';

const _languageNames = {'es': 'Español', 'pt': 'Português', 'en': 'English'};

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key, required this.church});

  final Church church;

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  final _url = TextEditingController();
  final _channelQuery = TextEditingController();
  final _start = TextEditingController(text: '00:00:00');
  final _end = TextEditingController();

  Map<String, dynamic>? _video;
  bool _busy = false;
  bool _waitingLong = false;
  String? _error;

  bool _pasteLink = false;
  List<Map<String, dynamic>>? _foundChannels;
  Map<String, dynamic>? _channel;
  List<Map<String, dynamic>> _lives = [];
  String? _nextLivesPage;
  bool _loadingLives = false;

  String? _captionCode;
  late String _outputLanguage = widget.church.defaultOutputLanguage ?? 'es';
  late String _bibleVersion = widget.church.defaultBibleVersionCode ?? 'RVR1960';
  bool _customRange = false;
  late int _days = widget.church.defaultDevotionalDays ?? 5;

  @override
  void dispose() {
    _url.dispose();
    _channelQuery.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _captions => List<Map<String, dynamic>>.from(_video?['languages'] as List? ?? const []);

  /// Queues a worker job and waits for it. Returns the job's result, or null after showing the error.
  Future<Map<String, dynamic>?> _runJob(String step, Map<String, dynamic> payload) async {
    final l = AppLocalizations.of(context)!;
    final repo = ref.read(repositoryProvider);
    setState(() {
      _waitingLong = false;
      _error = null;
    });
    try {
      final jobId = await repo.createJob(step, payload, churchId: widget.church.id);
      final started = DateTime.now();
      while (true) {
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!mounted) return null;
        final job = await repo.job(jobId);
        if (job.status == 'failed') {
          setState(() => _error = job.error ?? l.genericError);
          return null;
        }
        if (job.status == 'succeeded') return job.result;
        if (job.status == 'queued' && DateTime.now().difference(started).inSeconds > 12 && !_waitingLong) {
          setState(() => _waitingLong = true);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = l.genericError);
      return null;
    } finally {
      if (mounted) setState(() => _waitingLong = false);
    }
  }

  Future<void> _findVideo() async {
    setState(() {
      _busy = true;
      _video = null;
    });
    try {
      final church = widget.church;
      final result = await _runJob('probe', {'url': _url.text.trim()});
      if (result == null || !mounted) return;
      final sermonLanguage = church.defaultSermonLanguage ?? 'es';
      setState(() {
        _video = result;
        // YouTube also lists auto-translated tracks, so prefer the church's language over the first track.
        final match = _captions.where((c) => (c['language_code'] as String).split('-').first == sermonLanguage);
        _captionCode = (match.isNotEmpty ? match.first : _captions.first)['language_code'] as String;
        _outputLanguage = church.defaultOutputLanguage ?? _outputLanguage;
        _bibleVersion = church.defaultBibleVersionCode ?? _bibleVersion;
        _days = church.defaultDevotionalDays ?? _days;
      });
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.genericError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _searchChannels() async {
    if (_channelQuery.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _foundChannels = null;
    });
    final result = await _runJob('channel_search', {'query': _channelQuery.text.trim()});
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result != null) _foundChannels = List<Map<String, dynamic>>.from(result['channels'] as List);
    });
  }

  Future<void> _openChannel(Map<String, dynamic> channel) async {
    setState(() {
      _channel = channel;
      _foundChannels = null;
      _lives = [];
      _nextLivesPage = null;
    });
    // Remembering is a convenience; the lives still load if it fails.
    final churchId = widget.church.id;
    ref
        .read(repositoryProvider)
        .rememberChannel(churchId, channel)
        .then((_) => ref.invalidate(recentChannelsProvider(churchId)), onError: (_) {});
    await _loadLives();
  }

  Future<void> _loadLives({bool older = false}) async {
    final channel = _channel!;
    setState(() => _loadingLives = true);
    final result = await _runJob('channel_lives', {
      'channel_id': channel['channel_id'],
      if (older) 'page_token': _nextLivesPage,
    });
    // The admin may have switched channels while this one was loading.
    if (!mounted || _channel != channel) return;
    setState(() {
      _loadingLives = false;
      if (result != null) {
        _lives = [..._lives, ...List<Map<String, dynamic>>.from(result['lives'] as List)];
        _nextLivesPage = result['next_page_token'] as String?;
      }
    });
  }

  void _pickLive(Map<String, dynamic> live) {
    _url.text = live['youtube_url'] as String;
    _findVideo();
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
      final church = widget.church;
      final sermonId = await repo.saveSermon(church.id, {
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
        churchId: church.id,
        sermonId: sermonId,
      );
      ref.invalidate(sermonsProvider(church.id));
      if (mounted) context.go('/c/${church.slug}/admin/sermons/$sermonId');
    } catch (e) {
      if (mounted) {
        setState(() => _error = SelahError.fromException(e) == 'monthly_limit_reached'
            ? l.monthlyLimitReached(widget.church.monthlySermonLimit ?? 0)
            : l.jobAlreadyRunning);
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
    final video = _video;
    return AdminPage(church: widget.church, backTo: '/c/${widget.church.slug}/admin', maxWidth: 640, children: [
      Eyebrow(l.importSermon),
      const SizedBox(height: 8),
      Text(l.newSermonTitle, style: text.headlineMedium),
      const SizedBox(height: 24),
      if (video == null && !_pasteLink) ..._channelPicker(l, text),
      if (video == null && _pasteLink) ...[
        TextField(
          controller: _url,
          enabled: !_busy,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(labelText: l.youtubeUrl, hintText: 'https://www.youtube.com/watch?v=…'),
          onSubmitted: (_) => _findVideo(),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: _busy ? null : _findVideo,
            child: Text(_busy ? l.searchingVideo : l.findVideo),
          ),
        ),
      ],
      if (video == null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _busy ? null : () => setState(() => _pasteLink = !_pasteLink),
            child: Text(_pasteLink ? l.pickFromChannel : l.pasteLinkInstead),
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
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _busy ? null : () => setState(() => _video = null),
            child: Text(l.changeVideo),
          ),
        ),
        const SizedBox(height: 10),
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

  /// Search a church's channel, or reopen a recent one, then pick one of its finished lives.
  List<Widget> _channelPicker(AppLocalizations l, TextTheme text) {
    final recent = ref.watch(recentChannelsProvider(widget.church.id)).value ?? const [];
    final found = _foundChannels;
    final channel = _channel;
    final date = DateFormat.MMMEd(l.localeName);
    return [
      TextField(
        controller: _channelQuery,
        enabled: !_busy,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          labelText: l.searchChannel,
          hintText: l.searchChannelHint,
          prefixIcon: const Icon(Icons.search),
        ),
        onSubmitted: (_) => _searchChannels(),
      ),
      if (_busy && found == null && !_loadingLives) ...[
        const SizedBox(height: 10),
        Text(l.searchingChannels, style: text.bodyMedium),
      ],
      if (found != null) ...[
        const SizedBox(height: 8),
        if (found.isEmpty) Text(l.noChannelsFound, style: text.bodyMedium),
        for (final c in found)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundImage: c['thumbnail_url'] == null ? null : NetworkImage(c['thumbnail_url'] as String),
            ),
            title: Text(c['title'] as String? ?? ''),
            subtitle: c['handle'] == null ? null : Text(c['handle'] as String),
            onTap: () => _openChannel(c),
          ),
      ],
      if (recent.isNotEmpty && found == null) ...[
        const SizedBox(height: 14),
        Text(l.recentChannels, style: text.labelLarge),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in recent)
            ChoiceChip(
              label: Text(c['title'] as String),
              selected: channel?['channel_id'] == c['channel_id'],
              onSelected: _busy ? null : (_) => _openChannel(c),
            ),
        ]),
      ],
      if (channel != null && found == null) ...[
        const SizedBox(height: 22),
        Text(l.livesFrom(channel['title'] as String), style: text.titleLarge),
        const SizedBox(height: 8),
        if (!_loadingLives && _lives.isEmpty && _error == null) Text(l.noLives, style: text.bodyMedium),
        for (final live in _lives)
          InkWell(
            onTap: _busy ? null : () => _pickLive(live),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(live['thumbnail_url'] as String,
                      width: 120, height: 68, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 120)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(live['title'] as String? ?? '', style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(
                      [
                        if (DateTime.tryParse(live['started_at'] as String? ?? '') case final started?)
                          date.format(started.toLocal()),
                        if (live['duration_seconds'] case final int seconds) clock(seconds),
                      ].join(' · '),
                      style: text.bodyMedium,
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        if (_loadingLives) ...[
          const SizedBox(height: 8),
          Text(l.loadingLives, style: text.bodyMedium),
        ] else if (_nextLivesPage != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: _busy ? null : () => _loadLives(older: true), child: Text(l.loadOlderLives)),
          ),
      ],
    ];
  }
}
