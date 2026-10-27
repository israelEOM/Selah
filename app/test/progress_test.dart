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
    expect(await loadDoneDates(), contains('2026-10-28'));
  });

  test('done dates span studies', () async {
    final d = day(1, reading: null, prayer: null);
    await togglePart('s1', d, DayPart.reflection, DateTime(2026, 10, 27));
    await togglePart('s2', d, DayPart.reflection, DateTime(2026, 10, 28));
    expect(await loadDoneDates(), {'2026-10-27', '2026-10-28'});
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
    expect(await loadDoneDates(), isEmpty);
  });

  test('old read marks count as done without a date', () async {
    SharedPreferences.setMockInitialValues({'read:s1': ['1', '2']});
    final p = await loadProgress('s1');
    expect(p.isDone(day(1)), isTrue);
    expect(p.isDone(day(2)), isTrue);
    expect(p.isDone(day(3)), isFalse);
    expect(await loadDoneDates(), isEmpty);
  });

  test('progress is per study', () async {
    await togglePart('s1', day(1), DayPart.reading, now);
    expect((await loadProgress('s2')).days, isEmpty);
    expect((await loadProgress('s1')).days[1]!.parts, {DayPart.reading});
  });

  test('localDate pads', () => expect(localDate(DateTime(2026, 1, 5)), '2026-01-05'));
}
