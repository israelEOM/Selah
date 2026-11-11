import '../../core/models.dart';
import '../../data/progress.dart';

sealed class TodayState {
  const TodayState();
}

class NoStudy extends TodayState {
  const NoStudy();
}

class DayToDo extends TodayState {
  const DayToDo(this.day);

  final DevotionalDay day;
}

class DoneForToday extends TodayState {
  const DoneForToday(this.day, this.next);

  final DevotionalDay day;
  final DevotionalDay? next;
}

class AllDone extends TodayState {
  const AllDone(this.passage, this.takeaway);

  final String? passage;
  final String? takeaway;
}

TodayState todayFor({required PublicStudy? study, required StudyProgress progress, required DateTime now}) {
  if (study == null) return const NoStudy();
  final today = localDate(now);
  final next = study.days.where((d) => !progress.isDone(d)).firstOrNull;
  final doneToday = study.days.where((d) => progress.days[d.number]?.doneOn == today).lastOrNull;
  if (doneToday != null) return DoneForToday(doneToday, next);
  if (next != null) return DayToDo(next);
  // The summary is model output stored as JSON, so ignore fields of the wrong type.
  final rawPassage = study.summary['main_passage'];
  final passage = rawPassage is String ? rawPassage : null;
  final rawTakeaways = study.summary['key_takeaways'];
  final takeaways = rawTakeaways is List ? rawTakeaways.whereType<String>().toList() : const <String>[];
  final dayOfYear = DateTime.utc(now.year, now.month, now.day).difference(DateTime.utc(now.year)).inDays + 1; // utc: DST-proof
  return AllDone(passage, takeaways.isEmpty ? null : takeaways[dayOfYear % takeaways.length]);
}

/// The newest study's day last worked on [date], or null when that date's last tick belongs elsewhere (or none was
/// made). The caller then shows the day [todayFor] would.
DevotionalDay? dayOnDate({required PublicStudy study, required Map<String, DateTicks> ticks, required String date}) {
  final last = ticks[date]?.lastDay;
  if (last == null || last.studyId != study.id) return null;
  return study.days.where((d) => d.number == last.day).firstOrNull;
}
