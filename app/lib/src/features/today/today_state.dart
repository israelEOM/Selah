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
  final passage = study.summary['main_passage'] as String?;
  final takeaways = List<String>.from(study.summary['key_takeaways'] as List? ?? const []);
  final dayOfYear = DateTime.utc(now.year, now.month, now.day).difference(DateTime.utc(now.year)).inDays + 1; // utc: DST-proof
  return AllDone(passage, takeaways.isEmpty ? null : takeaways[dayOfYear % takeaways.length]);
}

/// Monday to Sunday of `now`'s week, true where a day was finished.
List<bool> weekCircles(Set<String> doneDates, DateTime now) {
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  return [for (var i = 0; i < 7; i++) doneDates.contains(localDate(DateTime(monday.year, monday.month, monday.day + i)))];
}
