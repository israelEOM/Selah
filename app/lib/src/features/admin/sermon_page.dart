import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../data/providers.dart';
import '../church/church_scope.dart';
import 'admin_gate.dart';

const _translateTargets = {'languages': ['en', 'pt']};
const _steps = ['transcript', 'analysis', 'summary', 'devotional'];

class SermonPage extends ConsumerWidget {
  const SermonPage({super.key, required this.church, required this.sermonId});

  final Church church;
  final String sermonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final detail = ref.watch(sermonDetailProvider(sermonId));
    final jobs = ref.watch(sermonJobsProvider(sermonId)).value ?? const <String, Job>{};

    // Reload the content whenever a step finishes.
    ref.listen(sermonJobsProvider(sermonId), (previous, next) {
      String signature(Map<String, Job>? m) => (m ?? const {}).values.map((j) => '${j.id}:${j.status}').join(',');
      if (signature(previous?.value) != signature(next.value)) {
        ref.invalidate(sermonDetailProvider(sermonId));
        ref.invalidate(sermonsProvider(church.id));
        final studyId = detail.value?.study?['id'] as String?;
        if (studyId != null) ref.invalidate(adminTranslationsProvider(studyId));
      }
    });

    // A sermon of another church is not reachable under this church's address.
    if (detail.value != null && detail.value!.sermon['church_id'] != church.id) {
      return ChurchMessage(text: l.churchNotFound, style: text.bodyLarge);
    }

    return AdminPage(
      church: church,
      backTo: '/c/${church.slug}/admin',
      children: detail.when(
        skipLoadingOnReload: true,
        loading: () => [const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))],
        error: (_, _) => [Text(l.loadError, style: text.bodyMedium)],
        data: (d) => [
          Eyebrow(studyStatusLabel(l, d.study?['status'] as String?)),
          const SizedBox(height: 8),
          Text((d.study?['title'] ?? d.sermon['title'] ?? '') as String, style: text.headlineMedium),
          const SizedBox(height: 6),
          Text(
            [d.sermon['preacher'], d.sermon['channel']].whereType<String>().join(' · '),
            style: text.bodyMedium,
          ),
          const SizedBox(height: 6),
          _Link(label: l.watchSermon, uri: youtubeAt(d.videoId, null)),
          const SizedBox(height: 28),
          _Progress(detail: d, jobs: jobs, churchId: church.id, sermonId: sermonId),
          const SizedBox(height: 32),
          _Analysis(detail: d),
          const SizedBox(height: 32),
          _References(detail: d, sermonId: sermonId),
          const SizedBox(height: 32),
          _Study(detail: d, jobs: jobs, churchId: church.id, sermonId: sermonId),
          if (d.study?['status'] == 'published') ...[
            const SizedBox(height: 32),
            _Translations(
              studyId: d.study!['id'] as String,
              churchId: church.id,
              sermonId: sermonId,
              job: jobs['translate'],
            ),
          ],
        ],
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.label, required this.uri});

  final String label;
  final Uri uri;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: Theme.of(context).colorScheme.primary),
          onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.play_circle_outline, size: 18),
          label: Text(label),
        ),
      );
}

class _Progress extends ConsumerWidget {
  const _Progress({required this.detail, required this.jobs, required this.churchId, required this.sermonId});

  final SermonDetail detail;
  final Map<String, Job> jobs;
  final String churchId;
  final String sermonId;

  bool _hasOutput(String step) => switch (step) {
        'transcript' => detail.hasTranscript,
        'analysis' => detail.analysis != null,
        'summary' => detail.study?['summary'] != null,
        _ => detail.days.isNotEmpty,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final labels = {
      'transcript': l.stepTranscript,
      'analysis': l.stepAnalysis,
      'summary': l.stepSummary,
      'devotional': l.stepDevotional,
    };
    final waiting = jobs.values.any((j) => j.status == 'queued' && DateTime.now().difference(j.createdAt).inSeconds > 15);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Eyebrow(l.progress),
      const SizedBox(height: 10),
      for (final step in _steps)
        Builder(builder: (context) {
          final job = jobs[step];
          // During a re-run, later steps still hold output from the previous run; show them as pending.
          final redoing = _steps.take(_steps.indexOf(step)).any((earlier) {
            final before = jobs[earlier];
            return before != null && before.status != 'succeeded' && (job == null || job.createdAt.isBefore(before.createdAt));
          });
          final status = redoing ? 'pending' : job?.status ?? (_hasOutput(step) ? 'succeeded' : 'pending');
          final Widget icon = switch (status) {
            'succeeded' => Icon(Icons.check_circle, color: context.tones.done, size: 22),
            'failed' => Icon(Icons.error, color: Theme.of(context).colorScheme.error, size: 22),
            'running' => const SizedBox(width: 22, height: 22, child: Padding(padding: EdgeInsets.all(2), child: CircularProgressIndicator(strokeWidth: 2.5))),
            'queued' => Icon(Icons.schedule, color: Theme.of(context).colorScheme.primary, size: 22),
            _ => Icon(Icons.circle_outlined, color: context.tones.muted, size: 22),
          };
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              icon,
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(labels[step]!, style: text.bodyLarge),
                  if (status == 'failed') ...[
                    Text(job?.error ?? l.genericError, style: text.bodyMedium),
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      // The failed job's payload carries the remaining steps, so a retry resumes the chain.
                      onPressed: () => ref.read(repositoryProvider).createJob(step, job!.payload, churchId: churchId, sermonId: sermonId),
                      child: Text(l.retryStep),
                    ),
                  ],
                ]),
              ),
            ]),
          );
        }),
      if (waiting) Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.workerHint, style: text.bodyMedium)),
    ]);
  }
}

class _Analysis extends StatelessWidget {
  const _Analysis({required this.detail});

  final SermonDetail detail;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final a = detail.analysis;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l.analysisSection, style: text.headlineSmall),
      const SizedBox(height: 10),
      if (a == null)
        Text(l.notGeneratedYet, style: text.bodyMedium)
      else ...[
        if (a['main_passage'] != null) Text('${l.mainPassage}: ${a['main_passage']}', style: text.bodyLarge),
        const SizedBox(height: 6),
        Text('${l.centralTheme}: ${a['central_theme']}', style: text.bodyMedium),
        if (a['sermon_start_seconds'] != null)
          _Link(
            label: '${clock(a['sermon_start_seconds'] as num?)} – ${clock(a['sermon_end_seconds'] as num?)}',
            uri: youtubeAt(detail.videoId, a['sermon_start_seconds'] as num?),
          ),
        const SizedBox(height: 14),
        Eyebrow(l.sermonPoints),
        const SizedBox(height: 8),
        for (final point in List<Map<String, dynamic>>.from(a['points'] as List))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(point['title'] as String, style: text.titleLarge),
                  const SizedBox(height: 6),
                  Text(point['summary'] as String, style: text.bodyMedium),
                  for (final sub in List<String>.from(point['subpoints'] as List))
                    Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $sub', style: text.bodyMedium)),
                  if ((point['references'] as List).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text((point['references'] as List).join(' · '), style: text.labelSmall),
                    ),
                  if (point['start_seconds'] != null)
                    _Link(
                      label: l.watchMoment(clock(point['start_seconds'] as num?)),
                      uri: youtubeAt(detail.videoId, point['start_seconds'] as num?),
                    ),
                ]),
              ),
            ),
          ),
      ],
    ]);
  }
}

class _References extends ConsumerWidget {
  const _References({required this.detail, required this.sermonId});

  final SermonDetail detail;
  final String sermonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    if (detail.references.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l.referencesSection, style: text.headlineSmall),
      const SizedBox(height: 4),
      Text(l.referencesHint, style: text.bodyMedium),
      const SizedBox(height: 10),
      Card(
        child: Column(children: [
          for (final r in detail.references)
            SwitchListTile(
              value: r['approved'] as bool,
              onChanged: (v) async {
                await ref.read(repositoryProvider).setReferenceApproved(r['id'] as String, v);
                ref.invalidate(sermonDetailProvider(sermonId));
              },
              title: Text(
                '${r['reference']}  ·  ${switch (r['classification']) { 'explicit' => l.refExplicit, 'quoted' => l.refQuoted, _ => l.refPossible }}'
                '  ·  ${clock(r['start_seconds'] as num?)}',
                style: text.bodyLarge,
              ),
              subtitle: Text('“${r['transcript_excerpt'] ?? ''}”', maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
        ]),
      ),
    ]);
  }
}

class _Study extends ConsumerStatefulWidget {
  const _Study({required this.detail, required this.jobs, required this.churchId, required this.sermonId});

  final SermonDetail detail;
  final Map<String, Job> jobs;
  final String churchId;
  final String sermonId;

  @override
  ConsumerState<_Study> createState() => _StudyState();
}

class _StudyState extends ConsumerState<_Study> {
  late int _days = (widget.detail.study?['number_of_days'] as int?) ?? 5;
  String? _notice;

  Future<void> _run(Future<void> Function() action, {String? notice}) async {
    final l = AppLocalizations.of(context)!;
    try {
      await action();
      ref.invalidate(sermonDetailProvider(widget.sermonId));
      ref.invalidate(sermonsProvider(widget.churchId));
      ref.invalidate(publishedStudiesProvider(widget.churchId));
      if (mounted) setState(() => _notice = notice);
    } catch (_) {
      if (mounted) setState(() => _notice = l.jobAlreadyRunning);
    }
  }

  /// Publishes, then queues the translation. A failure queuing it must not hide that the study is live.
  Future<void> _publish(String studyId) async {
    final l = AppLocalizations.of(context)!;
    final repo = ref.read(repositoryProvider);
    try {
      await repo.setStudyPublished(studyId, true);
    } catch (_) {
      if (mounted) setState(() => _notice = l.jobAlreadyRunning);
      return;
    }
    var notice = l.published;
    try {
      await repo.createJob('translate', _translateTargets, churchId: widget.churchId, sermonId: widget.sermonId);
    } catch (_) {
      notice = l.publishedWithoutTranslation;
    }
    ref.invalidate(sermonDetailProvider(widget.sermonId));
    ref.invalidate(sermonsProvider(widget.churchId));
    ref.invalidate(publishedStudiesProvider(widget.churchId));
    if (mounted) setState(() => _notice = notice);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final repo = ref.read(repositoryProvider);
    final study = widget.detail.study;
    final days = widget.detail.days;
    final busy = widget.jobs.values.any((j) => j.isActive);
    if (study == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.studySection, style: text.headlineSmall),
        const SizedBox(height: 10),
        Text(l.notGeneratedYet, style: text.bodyMedium),
      ]);
    }
    final summary = (study['summary'] as Map<String, dynamic>?) ?? const {};
    final published = study['status'] == 'published';
    final studyPayload = {
      'output_language': study['output_language'],
      'bible_version_code': study['bible_version_code'],
      'number_of_days': _days,
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l.studySection, style: text.headlineSmall),
      const SizedBox(height: 10),
      Text(study['central_message'] as String? ?? '', style: text.bodyLarge),
      if ((summary['key_takeaways'] as List?)?.isNotEmpty ?? false) ...[
        const SizedBox(height: 14),
        Eyebrow(l.keyTakeaways),
        for (final t in List<String>.from(summary['key_takeaways'] as List))
          Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $t', style: text.bodyMedium)),
      ],
      const SizedBox(height: 18),
      for (final day in days)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              shape: const Border(),
              title: Text('${l.dayLabel(day['day_number'] as int)} · ${day['title']}', style: text.titleLarge),
              subtitle: Text(day['bible_reading'] as String? ?? ''),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field(context, l.mainIdea, day['main_idea'] as String?),
                _field(context, l.reflection, day['reflection'] as String?),
                _field(context, l.application, day['application'] as String?),
                _field(context, l.questions, List<String>.from(day['questions'] as List).map((q) => '• $q').join('\n')),
                _field(context, l.prayer, day['prayer'] as String?),
                if (day['start_seconds'] != null)
                  _Link(
                    label: l.watchMoment(clock(day['start_seconds'] as num?)),
                    uri: youtubeAt(widget.detail.videoId, day['start_seconds'] as num?),
                  ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (days.isNotEmpty)
          FilledButton(
            onPressed: busy
                ? null
                : published
                    ? () => _run(() => repo.setStudyPublished(study['id'] as String, false))
                    : () => _publish(study['id'] as String),
            child: Text(published ? l.unpublish : l.publish),
          ),
        SegmentedButton<int>(
          segments: [for (final d in const [1, 3, 5, 7]) ButtonSegment(value: d, label: Text('$d'))],
          selected: {_days},
          onSelectionChanged: (s) => setState(() => _days = s.first),
        ),
        OutlinedButton(
          onPressed: busy
              ? null
              : () => _run(() => repo.createJob('devotional', {'days': _days}, churchId: widget.churchId, sermonId: widget.sermonId)),
          child: Text(l.regenerateDevotional),
        ),
        TextButton(
          onPressed: busy
              ? null
              : () => _run(() => repo.createJob(
                    'analysis',
                    {
                      'chain': [
                        {'step': 'summary', 'payload': studyPayload},
                        {
                          'step': 'devotional',
                          'payload': {'days': _days},
                        },
                      ],
                    },
                    churchId: widget.churchId,
                    sermonId: widget.sermonId,
                  )),
          child: Text(l.regenerateAll),
        ),
      ]),
      if (_notice != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_notice!, style: text.bodyMedium)),
    ]);
  }

  Widget _field(BuildContext context, String label, String? value) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Eyebrow(label),
          const SizedBox(height: 4),
          Text(value ?? '', style: Theme.of(context).textTheme.bodyMedium),
        ]),
      );
}

const _languageNames = {'en': 'Inglés', 'pt': 'Portugués (Brasil)'};

class _Translations extends ConsumerWidget {
  const _Translations({required this.studyId, required this.churchId, required this.sermonId, required this.job});

  final String studyId;
  final String churchId;
  final String sermonId;
  final Job? job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final repo = ref.read(repositoryProvider);
    final rows = ref.watch(adminTranslationsProvider(studyId)).value ?? const <Map<String, dynamic>>[];
    final active = job?.isActive ?? false;

    Future<void> setHidden(String id, bool hidden) async {
      await repo.setTranslationHidden(id, hidden);
      ref.invalidate(adminTranslationsProvider(studyId));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.translationsSection, style: text.headlineSmall),
        const SizedBox(height: 10),
        if (active)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                job!.status == 'running'
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Icon(Icons.schedule, color: Theme.of(context).colorScheme.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(l.stepTranslate, style: text.bodyMedium)),
              ],
            ),
          ),
        if (job?.status == 'failed')
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              job!.error ?? l.genericError,
              style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ExpansionTile(
                    shape: const Border(),
                    title: Text(_languageNames[row['language']] ?? '${row['language']}', style: text.titleLarge),
                    subtitle: Text(
                      '${(row['hidden'] as bool? ?? true) ? l.translationPending : l.translationLive}'
                      ' · ${(row['created_at'] as String? ?? '').split('T').first}',
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row['title'] as String? ?? '', style: text.titleLarge),
                      const SizedBox(height: 6),
                      Text(row['central_message'] as String? ?? '', style: text.bodyLarge),
                      for (final day in List<Map<String, dynamic>>.from((row['days'] as List?) ?? const []))
                        _TranslatedDay(day: day),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: (row['hidden'] as bool? ?? true)
                          ? FilledButton(
                              onPressed: () => setHidden(row['id'] as String, false),
                              child: Text(l.approveTranslation),
                            )
                          : OutlinedButton(
                              onPressed: () => setHidden(row['id'] as String, true),
                              child: Text(l.withdrawTranslation),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            TextButton(
              onPressed: active
                  ? null
                  : () async {
                      try {
                        await repo.createJob('translate', _translateTargets, churchId: churchId, sermonId: sermonId);
                        ref.invalidate(sermonJobsProvider(sermonId));
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.jobAlreadyRunning)));
                        }
                      }
                    },
              child: Text(l.translateAgain),
            ),
          ],
        ),
      ],
    );
  }
}

class _TranslatedDay extends StatelessWidget {
  const _TranslatedDay({required this.day});

  final Map<String, dynamic> day;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    Widget field(String label, String? value) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(label),
          const SizedBox(height: 4),
          Text(value ?? '', style: text.bodyMedium),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${l.dayLabel(day['day_number'] as int)} · ${day['title']}', style: text.titleMedium),
          field(l.mainIdea, day['main_idea'] as String?),
          field(l.reflection, day['reflection'] as String?),
          field(l.application, day['application'] as String?),
          field(l.questions, List<String>.from((day['questions'] as List?) ?? const []).map((q) => '• $q').join('\n')),
          field(l.prayer, day['prayer'] as String?),
        ],
      ),
    );
  }
}
