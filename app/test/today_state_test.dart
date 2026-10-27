import 'package:flutter_test/flutter_test.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/progress.dart';
import 'package:selah/src/features/today/today_state.dart';

DevotionalDay day(int n) => DevotionalDay(number: n, title: 'D$n', questions: const [], reflection: 'r');

PublicStudy study({int days = 5, Map<String, dynamic> summary = const {}}) => PublicStudy(
      id: 's1',
      slug: 'slug',
      title: 'T',
      numberOfDays: days,
      bibleVersionCode: 'RVR60',
      summary: summary,
      sermon: const SermonInfo(videoId: 'v'),
      days: [for (var i = 1; i <= days; i++) day(i)],
    );

DayProgress finished(String? on) => DayProgress(parts: const {DayPart.reflection}, doneOn: on);

void main() {
  final s = study();

  test('no study', () {
    expect(todayFor(study: null, progress: const StudyProgress({}), now: DateTime(2026, 10, 28)), isA<NoStudy>());
  });

  test('fresh study shows day 1', () {
    final r = todayFor(study: s, progress: const StudyProgress({}), now: DateTime(2026, 10, 28));
    expect((r as DayToDo).day.number, 1);
  });

  test('skipping ahead still shows the lowest unfinished', () {
    final r = todayFor(study: s, progress: StudyProgress({3: finished(null)}), now: DateTime(2026, 10, 28));
    expect((r as DayToDo).day.number, 1);
  });

  test('finishing today holds until tomorrow', () {
    final p = StudyProgress({1: finished('2026-10-28')});
    final r = todayFor(study: s, progress: p, now: DateTime(2026, 10, 28, 23, 50));
    expect(r, isA<DoneForToday>());
    expect((r as DoneForToday).day.number, 1);
    expect(r.next?.number, 2);
    final t = todayFor(study: s, progress: p, now: DateTime(2026, 10, 29, 0, 10));
    expect((t as DayToDo).day.number, 2);
  });

  test('last day finished today, then all done', () {
    final days = {for (var i = 1; i <= 4; i++) i: finished('2026-10-27'), 5: finished('2026-10-28')};
    final withSummary = study(summary: {'main_passage': 'Lucas 9:23-27', 'key_takeaways': ['a', 'b', 'c']});
    final r = todayFor(study: withSummary, progress: StudyProgress(days), now: DateTime(2026, 10, 28, 20));
    expect((r as DoneForToday).day.number, 5);
    expect(r.next, isNull);
    final t = todayFor(study: withSummary, progress: StudyProgress(days), now: DateTime(2026, 10, 29));
    expect(t, isA<AllDone>());
    expect((t as AllDone).passage, 'Lucas 9:23-27');
    // Oct 29 is day 302 of 2026; 302 % 3 == 2
    expect(t.takeaway, 'c');
  });

  test('DoneForToday names the highest day finished today', () {
    final p = StudyProgress({1: finished('2026-10-28'), 2: finished('2026-10-28')});
    final r = todayFor(study: s, progress: p, now: DateTime(2026, 10, 28)) as DoneForToday;
    expect(r.day.number, 2);
    expect(r.next?.number, 3);
  });

  test('all done with no summary', () {
    final p = StudyProgress({for (var i = 1; i <= 5; i++) i: finished('2026-10-20')});
    final r = todayFor(study: s, progress: p, now: DateTime(2026, 10, 28)) as AllDone;
    expect(r.passage, isNull);
    expect(r.takeaway, isNull);
  });

  test('weekCircles ignores other weeks and spans studies', () {
    final circles = weekCircles({'2026-10-26', '2026-10-27', '2026-10-28', '2026-10-21'}, DateTime(2026, 10, 29));
    expect(circles, [true, true, true, false, false, false, false]);
  });

  test('weekCircles on a Sunday covers the week before it', () {
    final circles = weekCircles({'2026-10-26', '2026-11-01'}, DateTime(2026, 11, 1));
    expect(circles, [true, false, false, false, false, false, true]);
  });
}
