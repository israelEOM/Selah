import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/progress.dart';
import '../../data/providers.dart';

/// Bumped whenever Today should read the clock and its data again.
final todayRefreshProvider = NotifierProvider<TodayRefresh, int>(TodayRefresh.new);

class TodayRefresh extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// Reloads Today: the church's newest study, the progress on it and the week's done days, with a fresh `now`.
Future<void> refreshToday(WidgetRef ref, String churchId) async {
  ref.invalidate(newestStudyProvider(churchId));
  ref.invalidate(studyProgressProvider);
  ref.invalidate(doneDatesProvider);
  ref.read(todayRefreshProvider.notifier).bump();
  try {
    await ref.read(newestStudyProvider(churchId).future);
  } catch (_) {
    // The page shows the error with its own retry.
  }
}

/// Keeps Today current: refreshes it when the app comes back to the foreground and at local midnight.
class TodayRefresher extends ConsumerStatefulWidget {
  const TodayRefresher({super.key, required this.churchId, required this.child});

  final String churchId;
  final Widget child;

  @override
  ConsumerState<TodayRefresher> createState() => _TodayRefresherState();
}

class _TodayRefresherState extends ConsumerState<TodayRefresher> {
  late final AppLifecycleListener _lifecycle;
  Timer? _midnight;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _scheduleMidnight();
  }

  void _refresh() {
    if (!mounted) return;
    refreshToday(ref, widget.churchId);
    _scheduleMidnight();
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = ref.read(clockProvider)();
    // A second past midnight, so the new day has surely begun.
    final next = DateTime(now.year, now.month, now.day + 1, 0, 0, 1);
    _midnight = Timer(next.difference(now), _refresh);
  }

  @override
  void dispose() {
    _midnight?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
