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
  const DayProgress({this.parts = const {}, this.doneOn});

  final Set<DayPart> parts;
  final String? doneOn;
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
        ),
    };
  } catch (_) {
    return {};
  }
}

String _encode(Map<int, DayProgress> days) => jsonEncode({
      for (final e in days.entries) '${e.key}': {'parts': [for (final p in e.value.parts) p.name], 'doneOn': e.value.doneOn},
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

Future<StudyProgress> togglePart(String studyId, DevotionalDay day, DayPart part, DateTime now) async {
  final prefs = await SharedPreferences.getInstance();
  final days = _read(prefs, studyId);
  final parts = {...?days[day.number]?.parts};
  if (!parts.remove(part)) parts.add(part);
  final done = parts.containsAll(partsFor(day));
  days[day.number] = DayProgress(parts: parts, doneOn: done ? localDate(now) : null);
  await prefs.setString(_key(studyId), _encode(days));
  return StudyProgress(days);
}

/// Every date a day was finished, across all studies.
Future<Set<String>> loadDoneDates() async {
  final prefs = await SharedPreferences.getInstance();
  return {
    for (final key in prefs.getKeys().where((k) => k.startsWith('progress:')))
      for (final d in _decode(prefs.getString(key)).values)
        if (d.doneOn != null) d.doneOn!,
  };
}

final studyProgressProvider = FutureProvider.autoDispose.family<StudyProgress, String>((ref, studyId) => loadProgress(studyId));

final doneDatesProvider = FutureProvider.autoDispose<Set<String>>((ref) => loadDoneDates());

Future<void> tickPart(WidgetRef ref, String studyId, DevotionalDay day, DayPart part, DateTime now) async {
  await togglePart(studyId, day, part, now);
  ref.invalidate(studyProgressProvider(studyId));
  ref.invalidate(doneDatesProvider);
}
