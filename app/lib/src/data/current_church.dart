import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models.dart';
import 'providers.dart';

const _preferenceKey = 'church';

/// The church slug saved before the app started; `main` overrides this once.
final savedChurchProvider = Provider<String?>((ref) => null);

final chosenChurchSlugProvider = NotifierProvider<ChosenChurch, String?>(ChosenChurch.new);

class ChosenChurch extends Notifier<String?> {
  @override
  String? build() => ref.watch(savedChurchProvider);

  Future<void> choose(String slug) async {
    state = slug;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferenceKey, slug);
  }
}

/// The church the app shows: the chosen one when it applies to this person, else their first church.
final currentChurchProvider = FutureProvider<Church?>((ref) async {
  final chosen = ref.watch(chosenChurchSlugProvider);
  final userId = await ref.watch(userIdProvider.future);
  final mine = userId == null ? const <Membership>[] : await ref.watch(myChurchesProvider.future);
  if (chosen != null && (mine.isEmpty || mine.any((m) => m.church.slug == chosen))) {
    final church = await ref.watch(churchProvider(chosen).future);
    if (church != null) return church;
  }
  return mine.isEmpty ? null : mine.first.church;
});

Future<String?> loadSavedChurch() async => (await SharedPreferences.getInstance()).getString(_preferenceKey);
