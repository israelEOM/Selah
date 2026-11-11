import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models.dart';

enum DayPart { reading, reflection, prayer }

/// The parts a day offers; a day with no content still has `reflection` so it can be ticked.
List<DayPart> partsFor(DevotionalDay day) {
  final parts = <DayPart>[
    if (day.bibleReading != null) DayPart.reading,
    if (day.reflection != null || day.application != null || day.questions.isNotEmpty) DayPart.reflection,
    if (day.prayer != null) DayPart.prayer,
  ];
  return parts.isEmpty ? const [DayPart.reflection] : parts;
}

/// Local calendar date as `yyyy-MM-dd`.
String localDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class DayProgress {
  const DayProgress({this.parts = const {}, this.doneOn, this.partsOn = const {}});

  final Set<DayPart> parts;
  final String? doneOn;

  /// The date (`yyyy-MM-dd`) each ticked part was recorded on. Ticks saved before this existed have none.
  final Map<DayPart, String> partsOn;
}

class StudyProgress {
  const StudyProgress(this.days);

  final Map<int, DayProgress> days;

  bool isDone(DevotionalDay d) {
    final progress = days[d.number];
    return progress != null && progress.parts.containsAll(partsFor(d));
  }
}

String _key(String studyId) => 'progress:$studyId';

Map<int, DayProgress> _decode(String? raw) {
  if (raw == null) return {};
  try {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final e in json.entries)
        int.parse(e.key): DayProgress(
          parts: {
            for (final name in ((e.value as Map<String, dynamic>)['parts'] as List? ?? const []))
              ...DayPart.values.where((p) => p.name == name),
          },
          doneOn: (e.value as Map<String, dynamic>)['doneOn'] as String?,
          partsOn: {
            for (final o in (((e.value as Map<String, dynamic>)['partsOn'] as Map?) ?? const {}).entries)
              for (final p in DayPart.values.where((p) => p.name == o.key))
                if (o.value is String) p: o.value as String,
          },
        ),
    };
  } catch (_) {
    return {};
  }
}

String _encode(Map<int, DayProgress> days) => jsonEncode({
      for (final e in days.entries)
        '${e.key}': {
          'parts': [for (final p in e.value.parts) p.name],
          'doneOn': e.value.doneOn,
          'partsOn': {for (final o in e.value.partsOn.entries) o.key.name: o.value},
        },
    });

/// Old `read:` marks count as every part done, with no date.
Map<int, DayProgress> _legacy(SharedPreferences prefs, String studyId) => {
      for (final n in prefs.getStringList('read:$studyId') ?? const <String>[])
        if (int.tryParse(n) != null) int.parse(n): DayProgress(parts: {...DayPart.values}),
    };

Map<int, DayProgress> _read(SharedPreferences prefs, String studyId) =>
    {..._legacy(prefs, studyId), ..._decode(prefs.getString(_key(studyId)))};

Future<StudyProgress> loadProgress(String studyId) async {
  final prefs = await SharedPreferences.getInstance();
  return StudyProgress(_read(prefs, studyId));
}

/// Ticks or unticks [part]. The tick is dated [on] (`yyyy-MM-dd`), or today when none is given.
Future<StudyProgress> togglePart(String studyId, DevotionalDay day, DayPart part, DateTime now, {String? on}) async {
  final prefs = await SharedPreferences.getInstance();
  final days = _read(prefs, studyId);
  final date = on ?? localDate(now);
  final parts = {...?days[day.number]?.parts};
  final partsOn = {...?days[day.number]?.partsOn};
  if (parts.remove(part)) {
    partsOn.remove(part);
  } else {
    parts.add(part);
    partsOn[part] = date;
  }
  final done = parts.containsAll(partsFor(day));
  days[day.number] = DayProgress(parts: parts, doneOn: done ? date : null, partsOn: partsOn);
  await prefs.setString(_key(studyId), _encode(days));
  return StudyProgress(days);
}

/// What was ticked on one date, across all studies.
class DateTicks {
  const DateTicks({required this.parts, required this.complete, required this.lastDay});

  final Set<DayPart> parts;

  /// True when a day was finished on this date.
  final bool complete;

  /// The day with the latest tick on this date. Times of day aren't stored, so this is the last one met
  /// walking studies in key order and days in ascending number.
  final ({String studyId, int day})? lastDay;
}

/// Ticks grouped by the date they were made. A finished day's undated parts (saved before part dates)
/// land on its `doneOn`; an unfinished day's undated parts land nowhere.
Future<Map<String, DateTicks>> loadTicksByDate() async {
  final prefs = await SharedPreferences.getInstance();
  final parts = <String, Set<DayPart>>{};
  final complete = <String>{};
  final last = <String, ({String studyId, int day})>{};
  final keys = prefs.getKeys().where((k) => k.startsWith('progress:')).toList()..sort();
  for (final key in keys) {
    final studyId = key.substring('progress:'.length);
    final days = _decode(prefs.getString(key));
    for (final n in days.keys.toList()..sort()) {
      final d = days[n]!;
      void add(String date, Iterable<DayPart> ps) {
        parts.putIfAbsent(date, () => {}).addAll(ps);
        last[date] = (studyId: studyId, day: n);
      }

      for (final e in d.partsOn.entries) {
        add(e.value, [e.key]);
      }
      final doneOn = d.doneOn;
      if (doneOn != null) {
        complete.add(doneOn);
        add(doneOn, d.parts.where((p) => !d.partsOn.containsKey(p)));
      }
    }
  }
  return {
    for (final date in parts.keys) date: DateTicks(parts: parts[date]!, complete: complete.contains(date), lastDay: last[date]),
  };
}

final studyProgressProvider = FutureProvider.autoDispose.family<StudyProgress, String>((ref, studyId) => loadProgress(studyId));

final ticksByDateProvider = FutureProvider.autoDispose<Map<String, DateTicks>>((ref) => loadTicksByDate());
