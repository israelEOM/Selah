import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'today_refresh.dart';

/// The date (`yyyy-MM-dd`) picked in Today's week, or null for today. Goes back to today whenever Today refreshes
/// (on resume, at midnight, on pull to refresh), so a new day never opens on an old selection.
final selectedDateProvider = NotifierProvider<SelectedDate, String?>(SelectedDate.new);

class SelectedDate extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(todayRefreshProvider);
    return null;
  }

  /// Picks [date]; null goes back to today.
  void select(String? date) => state = date;
}

/// The day a tick has just finished, until Today plays moment A for it.
final justFinishedProvider = NotifierProvider<JustFinished, ({String studyId, int day})?>(JustFinished.new);

class JustFinished extends Notifier<({String studyId, int day})?> {
  @override
  ({String studyId, int day})? build() => null;

  void set(({String studyId, int day}) day) => state = day;

  void clear() => state = null;
}
