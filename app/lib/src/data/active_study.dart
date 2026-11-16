import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models.dart';
import 'progress.dart';
import 'providers.dart';

/// How far through a study someone is, from their saved progress. A day counts as done once it has a finish date,
/// or all three parts (old `read:` marks have no date).
({int done, int current}) studyStanding(StudyProgress? progress, int numberOfDays) {
  bool isDone(int n) {
    final day = progress?.days[n];
    return day != null && (day.doneOn != null || day.parts.containsAll(DayPart.values));
  }

  final done = [for (var n = 1; n <= numberOfDays; n++) if (isDone(n)) n];
  final current = [for (var n = 1; n <= numberOfDays; n++) n].where((n) => !isDone(n)).firstOrNull ?? numberOfDays;
  return (done: done.length, current: current);
}

/// Whether anything in a study has been ticked.
bool studyStarted(StudyProgress? progress) =>
    progress != null && progress.days.values.any((d) => d.parts.isNotEmpty || d.doneOn != null);

bool _finished(StudyCard study, StudyProgress? progress) =>
    study.numberOfDays > 0 && studyStanding(progress, study.numberOfDays).done == study.numberOfDays;

/// The latest date (`yyyy-MM-dd`) anything in [progress] was ticked or finished; empty when none is recorded.
String _lastTouched(StudyProgress? progress) {
  var last = '';
  for (final d in progress?.days.values ?? const <DayProgress>[]) {
    for (final date in [...d.partsOn.values, ?d.doneOn]) {
      if (date.compareTo(last) > 0) last = date;
    }
  }
  return last;
}

/// The latest date a day of [progress] was finished; empty when none is recorded.
String _finishedOn(StudyProgress? progress) {
  var last = '';
  for (final d in progress?.days.values ?? const <DayProgress>[]) {
    final done = d.doneOn;
    if (done != null && done.compareTo(last) > 0) last = done;
  }
  return last;
}

DateTime _generated(StudyCard s) => s.createdAt ?? s.publishedAt ?? DateTime.utc(1970);

/// The Sunday a study comes from (`yyyy-MM-dd`): its sermon's date, or the day it was generated.
String _sunday(StudyCard s) => localDate(s.sermonDate ?? _generated(s));

/// [studies] oldest generated first.
List<StudyCard> _byGeneration(List<StudyCard> studies) => [...studies]..sort((a, b) {
    final c = _generated(a).compareTo(_generated(b));
    return c != 0 ? c : a.id.compareTo(b.id);
  });

/// Studies as the church page lists them: the newest Sunday first, and each Sunday's studies in the order they were
/// generated, so a morning service comes before the evening one however they were published.
List<StudyCard> inReadingOrder(List<StudyCard> studies) {
  final order = _byGeneration(studies);
  final index = {for (final (i, s) in order.indexed) s.id: i};
  return order
    ..sort((a, b) {
      final c = _sunday(b).compareTo(_sunday(a));
      return c != 0 ? c : index[a.id]!.compareTo(index[b.id]!);
    });
}

/// The study someone is reading, which Today follows:
/// 1. the study they chose with Start or Continue, until a day after they finish it;
/// 2. else the study in progress they ticked last (one finished today still counts, so its finish shows);
/// 3. else the first unfinished study generated after the one they finished last, or that one when none is left;
/// 4. else, for someone who hasn't started anything, the first study generated from the latest Sunday.
///
/// [progress] is by study id; [today] is `yyyy-MM-dd`. Null when there are no studies.
String? activeStudyId({
  required List<StudyCard> studies,
  required Map<String, StudyProgress> progress,
  required String? chosenId,
  required String today,
}) {
  if (studies.isEmpty) return null;
  final order = _byGeneration(studies);
  bool current(StudyCard s) => !_finished(s, progress[s.id]) || _finishedOn(progress[s.id]) == today;

  final chosen = order.where((s) => s.id == chosenId).firstOrNull;
  if (chosen != null && current(chosen)) return chosen.id;

  StudyCard? latest(Iterable<StudyCard> candidates, String Function(StudyProgress?) date) {
    StudyCard? best;
    for (final s in candidates) {
      // Ties go to the later generated study, met later in [order].
      if (best == null || date(progress[s.id]).compareTo(date(progress[best.id])) >= 0) best = s;
    }
    return best;
  }

  final inProgress = latest(order.where((s) => studyStarted(progress[s.id]) && current(s)), _lastTouched);
  if (inProgress != null) return inProgress.id;

  final lastFinished = latest(order.where((s) => _finished(s, progress[s.id])), _finishedOn);
  if (lastFinished != null) {
    final after = order.skip(order.indexOf(lastFinished) + 1);
    return (after.where((s) => !_finished(s, progress[s.id])).firstOrNull ?? lastFinished).id;
  }

  final sunday = order.map(_sunday).reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
  return order.firstWhere((s) => _sunday(s) == sunday).id;
}

/// A study from a later Sunday than [activeId] that hasn't been started, for Today's "new study" notice; the first
/// generated when there are several. Null when there is none.
StudyCard? newerStudy({
  required List<StudyCard> studies,
  required String activeId,
  required Map<String, StudyProgress> progress,
}) {
  final active = studies.where((s) => s.id == activeId).firstOrNull;
  if (active == null) return null;
  return _byGeneration(studies)
      .where((s) => _sunday(s).compareTo(_sunday(active)) > 0 && !studyStarted(progress[s.id]))
      .firstOrNull;
}

String _chosenKey(String churchId) => 'active-study:$churchId';

const _dismissedKey = 'new-study-dismissed';

/// The study someone picked with Start or Continue in a church, by church id; null when they haven't picked one.
final chosenStudyProvider = FutureProvider.autoDispose.family<String?, String>((ref, churchId) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_chosenKey(churchId));
});

/// Makes [studyId] the study Today follows in [churchId].
Future<void> chooseStudy(WidgetRef ref, String churchId, String studyId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_chosenKey(churchId), studyId);
  ref.invalidate(chosenStudyProvider(churchId));
}

/// Saved progress on each of a church's published studies, by study id. Follows every tick, since ticks invalidate
/// [studyProgressProvider].
final churchProgressProvider = FutureProvider.autoDispose.family<Map<String, StudyProgress>, String>((ref, churchId) async {
  final studies = await ref.watch(publishedStudiesProvider(churchId).future);
  return {for (final s in studies) s.id: await ref.watch(studyProgressProvider(s.id).future)};
});

/// The id of the study Today follows in a church; see [activeStudyId].
final activeStudyIdProvider = FutureProvider.autoDispose.family<String?, String>((ref, churchId) async {
  final studies = await ref.watch(publishedStudiesProvider(churchId).future);
  final progress = await ref.watch(churchProgressProvider(churchId).future);
  final chosen = await ref.watch(chosenStudyProvider(churchId).future);
  return activeStudyId(
    studies: studies,
    progress: progress,
    chosenId: chosen,
    today: localDate(ref.watch(clockProvider)()),
  );
});

/// The study Today follows in a church, with its days. Fetched again only when a different study becomes active, so a
/// tick doesn't reload it.
final activeStudyProvider = FutureProvider.autoDispose.family<PublicStudy?, String>((ref, churchId) async {
  final id = await ref.watch(activeStudyIdProvider(churchId).selectAsync((id) => id));
  if (id == null) return null;
  final studies = await ref.read(publishedStudiesProvider(churchId).future);
  final card = studies.where((s) => s.id == id).firstOrNull;
  return card == null ? null : ref.read(repositoryProvider).studyBySlug(churchId, card.slug);
});

/// A newer study to point out on Today while someone is on an older one, unless they dismissed it; null otherwise.
final newStudyNoticeProvider = FutureProvider.autoDispose.family<StudyCard?, String>((ref, churchId) async {
  final activeId = await ref.watch(activeStudyIdProvider(churchId).future);
  if (activeId == null) return null;
  final newer = newerStudy(
    studies: await ref.watch(publishedStudiesProvider(churchId).future),
    activeId: activeId,
    progress: await ref.watch(churchProgressProvider(churchId).future),
  );
  if (newer == null) return null;
  final prefs = await SharedPreferences.getInstance();
  return (prefs.getStringList(_dismissedKey) ?? const []).contains(newer.id) ? null : newer;
});

/// Hides the notice for [studyId] for good.
Future<void> dismissNewStudy(WidgetRef ref, String churchId, String studyId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_dismissedKey, {...?prefs.getStringList(_dismissedKey), studyId}.toList());
  ref.invalidate(newStudyNoticeProvider(churchId));
}
