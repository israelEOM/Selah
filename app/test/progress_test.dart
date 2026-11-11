import 'package:flutter_test/flutter_test.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

DevotionalDay day(int n, {String? reading = 'Lc 9', String? reflection = 'r', String? prayer = 'p', List<String> questions = const []}) =>
    DevotionalDay(number: n, title: 'D$n', questions: questions, bibleReading: reading, reflection: reflection, prayer: prayer);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('partsFor', () {
    test('full day', () => expect(partsFor(day(1)), DayPart.values));
    test('no reading', () => expect(partsFor(day(1, reading: null)), [DayPart.reflection, DayPart.prayer]));
    test('no prayer', () => expect(partsFor(day(1, prayer: null)), [DayPart.reading, DayPart.reflection]));
    test('only questions', () => expect(partsFor(day(1, reading: null, reflection: null, prayer: null, questions: ['q'])), [DayPart.reflection]));
    test('nothing', () => expect(partsFor(day(1, reading: null, reflection: null, prayer: null)), [DayPart.reflection]));
  });

  final now = DateTime(2026, 10, 28, 9);

  test('ticking every part marks the day done today', () async {
    final d = day(1);
    late StudyProgress p;
    for (final part in DayPart.values) {
      p = await togglePart('s1', d, part, now);
    }
    expect(p.isDone(d), isTrue);
    expect(p.days[1]!.doneOn, '2026-10-28');
    expect((await loadProgress('s1')).isDone(d), isTrue);
  });

  test('each tick records its own date', () async {
    final d = day(1);
    await togglePart('s1', d, DayPart.reading, DateTime(2026, 10, 27, 9));
    final p = await togglePart('s1', d, DayPart.reflection, DateTime(2026, 10, 28, 9));
    expect(p.days[1]!.partsOn, {DayPart.reading: '2026-10-27', DayPart.reflection: '2026-10-28'});
    final byDate = await loadTicksByDate();
    expect(byDate['2026-10-27']!.parts, {DayPart.reading});
    expect(byDate['2026-10-28']!.parts, {DayPart.reflection});
    expect(byDate['2026-10-28']!.complete, isFalse);
  });

  test('a tick made for a past date lands on that date and finishes the day there', () async {
    final d = day(1);
    for (final part in DayPart.values) {
      await togglePart('s1', d, part, DateTime(2026, 10, 28, 9), on: '2026-10-27');
    }
    final byDate = await loadTicksByDate();
    expect(byDate['2026-10-27']!.complete, isTrue);
    expect(byDate['2026-10-27']!.lastDay, (studyId: 's1', day: 1));
    expect(byDate.containsKey('2026-10-28'), isFalse);
    expect((await loadProgress('s1')).days[1]!.doneOn, '2026-10-27');
  });

  test('unticking removes the part from its date', () async {
    await togglePart('s1', day(1), DayPart.reading, now);
    await togglePart('s1', day(1), DayPart.reading, now);
    expect(await loadTicksByDate(), isEmpty);
  });

  test('progress saved before part dates still loads and lands on doneOn', () async {
    SharedPreferences.setMockInitialValues({
      'progress:s1': '{"1":{"parts":["reading","reflection","prayer"],"doneOn":"2026-10-20"},"2":{"parts":["reading"],"doneOn":null}}',
      'read:s2': ['1'],
    });
    final byDate = await loadTicksByDate();
    expect(byDate.keys, ['2026-10-20']);
    expect(byDate['2026-10-20']!.complete, isTrue);
    expect((await loadProgress('s1')).days[2]!.parts, {DayPart.reading});
  });

  test('done dates span studies', () async {
    final d = day(1, reading: null, prayer: null);
    await togglePart('s1', d, DayPart.reflection, DateTime(2026, 10, 27));
    await togglePart('s2', d, DayPart.reflection, DateTime(2026, 10, 28));
    final byDate = await loadTicksByDate();
    expect(byDate.keys.toSet(), {'2026-10-27', '2026-10-28'});
    expect(byDate['2026-10-28']!.lastDay, (studyId: 's2', day: 1));
  });

  test('a day without prayer is done after reading and reflection', () async {
    final d = day(1, prayer: null);
    await togglePart('s1', d, DayPart.reading, now);
    final p = await togglePart('s1', d, DayPart.reflection, now);
    expect(p.isDone(d), isTrue);
  });

  test('unticking clears done', () async {
    final d = day(1);
    for (final part in DayPart.values) {
      await togglePart('s1', d, part, now);
    }
    final p = await togglePart('s1', d, DayPart.prayer, now);
    expect(p.isDone(d), isFalse);
    expect(p.days[1]!.doneOn, isNull);
    expect(await loadTicksByDate(), isEmpty);
  });

  test('old read marks count as done without a date', () async {
    SharedPreferences.setMockInitialValues({'read:s1': ['1', '2']});
    final p = await loadProgress('s1');
    expect(p.isDone(day(1)), isTrue);
    expect(p.isDone(day(2)), isTrue);
    expect(p.isDone(day(3)), isFalse);
    expect(await loadTicksByDate(), isEmpty);
  });

  test('progress is per study', () async {
    await togglePart('s1', day(1), DayPart.reading, now);
    expect((await loadProgress('s2')).days, isEmpty);
    expect((await loadProgress('s1')).days[1]!.parts, {DayPart.reading});
  });

  test('localDate pads', () => expect(localDate(DateTime(2026, 1, 5)), '2026-01-05'));
}
