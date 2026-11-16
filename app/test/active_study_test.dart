import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/active_study.dart';
import 'package:selah/src/data/progress.dart';
import 'package:selah/src/data/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A 2-day study preached on [sunday] and generated at [hour] that Monday.
StudyCard _study(String id, String sunday, int hour) => StudyCard(
      id: id,
      slug: id,
      title: id,
      numberOfDays: 2,
      sermonDate: DateTime.parse(sunday),
      createdAt: DateTime.parse(sunday).add(Duration(days: 1, hours: hour)),
    );

const _all = {DayPart.reading, DayPart.reflection, DayPart.prayer};

/// Day 1 ticked on [on].
StudyProgress _started(String on) => StudyProgress({1: DayProgress(parts: _all, doneOn: on, partsOn: {for (final p in _all) p: on})});

/// Both days finished, the last on [on].
StudyProgress _finished(String on) => StudyProgress({
      1: DayProgress(parts: _all, doneOn: on),
      2: DayProgress(parts: _all, doneOn: on),
    });

void main() {
  // Last week's study, then Sunday's two: morning generated before evening.
  final lastWeek = _study('last-week', '2026-11-08', 9);
  final morning = _study('morning', '2026-11-15', 9);
  final evening = _study('evening', '2026-11-15', 11);
  // Published evening first, to prove publish order doesn't matter.
  final studies = [evening, lastWeek, morning];
  const today = '2026-11-16';

  String? active({Map<String, StudyProgress> progress = const {}, String? chosen}) =>
      activeStudyId(studies: studies, progress: progress, chosenId: chosen, today: today);

  group('activeStudyId', () {
    test('with nothing started, opens the first study generated from the latest Sunday', () {
      expect(active(), 'morning');
    });

    test('keeps a study in progress even when newer ones exist', () {
      expect(active(progress: {'last-week': _started('2026-11-14')}), 'last-week');
    });

    test('after finishing a study, moves to the next one generated after it', () {
      expect(active(progress: {'last-week': _finished('2026-11-15')}), 'morning');
    });

    test('after finishing the morning study, moves to the evening one', () {
      expect(active(progress: {'last-week': _finished('2026-11-10'), 'morning': _finished('2026-11-15')}), 'evening');
    });

    test('stays on a study finished today, so its finish shows', () {
      expect(active(progress: {'last-week': _finished(today)}), 'last-week');
    });

    test('with everything finished, stays on the last one finished', () {
      expect(
        active(progress: {
          'last-week': _finished('2026-11-10'),
          'morning': _finished('2026-11-12'),
          'evening': _finished('2026-11-14'),
        }),
        'evening',
      );
    });

    test('a study the person chose wins over one in progress', () {
      expect(active(progress: {'last-week': _started('2026-11-14')}, chosen: 'evening'), 'evening');
    });

    test('a chosen study once finished hands back to the one left in progress', () {
      expect(
        active(progress: {'last-week': _started('2026-11-12'), 'evening': _finished('2026-11-15')}, chosen: 'evening'),
        'last-week',
      );
    });

    test('ignores a chosen study that is no longer published', () {
      expect(active(chosen: 'gone'), 'morning');
    });

    test('with two in progress, follows the one ticked most recently', () {
      expect(active(progress: {'last-week': _started('2026-11-15'), 'morning': _started('2026-11-14')}), 'last-week');
    });

    test('is null with no studies', () {
      expect(activeStudyId(studies: const [], progress: const {}, chosenId: null, today: today), isNull);
    });
  });

  group('inReadingOrder', () {
    test('puts the newest Sunday first, and each Sunday in the order generated', () {
      expect(inReadingOrder(studies).map((s) => s.id), ['morning', 'evening', 'last-week']);
    });
  });

  group('newerStudy', () {
    test('names the first study from a later Sunday that has not been started', () {
      expect(newerStudy(studies: studies, activeId: 'last-week', progress: const {})?.id, 'morning');
    });

    test('is null when the active study is from the latest Sunday', () {
      expect(newerStudy(studies: studies, activeId: 'morning', progress: const {}), isNull);
    });

    test('skips studies already started', () {
      expect(
        newerStudy(studies: studies, activeId: 'last-week', progress: {'morning': _started('2026-11-16')})?.id,
        'evening',
      );
    });
  });

  group('studyStarted', () {
    test('is true once any part is ticked', () {
      expect(studyStarted(_started('2026-11-16')), isTrue);
      expect(studyStarted(const StudyProgress({})), isFalse);
      expect(studyStarted(null), isFalse);
    });
  });

  group('activeStudyIdProvider', () {
    ProviderContainer container(Map<String, Object> prefs) {
      SharedPreferences.setMockInitialValues(prefs);
      final c = ProviderContainer(overrides: [
        publishedStudiesProvider('A').overrideWith((ref) async => studies),
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 16, 9)),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('follows saved progress', () async {
      final c = container({'progress:last-week': '{"1":{"parts":["reading"],"partsOn":{"reading":"2026-11-14"}}}'});
      expect(await c.read(activeStudyIdProvider('A').future), 'last-week');
    });

    test('follows the study saved as chosen for that church', () async {
      final c = container({'active-study:A': 'evening'});
      expect(await c.read(activeStudyIdProvider('A').future), 'evening');
    });
  });
}
