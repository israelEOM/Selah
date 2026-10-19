import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models.dart';
import 'repository.dart';

final repositoryProvider = Provider<SelahRepository>((_) => throw UnimplementedError());

/// The signed-in user's id, or null. Account-scoped providers watch it so state resets on sign-out.
final userIdProvider = StreamProvider<String?>((ref) {
  final auth = Supabase.instance.client.auth;
  return Stream<String?>.multi((controller) {
    controller.add(auth.currentUser?.id);
    final sub = auth.onAuthStateChange
        .listen((e) => controller.add(e.session?.user.id), onError: (_) => controller.add(auth.currentUser?.id));
    controller.onCancel = sub.cancel;
  }).distinct();
});

final isAdminProvider = FutureProvider<bool>((ref) async {
  final userId = ref.watch(userIdProvider).value;
  if (userId == null) return false;
  return ref.watch(repositoryProvider).isAdmin(userId);
});

final publishedStudiesProvider =
    FutureProvider<List<StudyCard>>((ref) => ref.watch(repositoryProvider).publishedStudies());

final sermonsProvider = FutureProvider<List<SermonRow>>((ref) {
  ref.watch(userIdProvider);
  return ref.watch(repositoryProvider).sermons();
});

final sermonDetailProvider = FutureProvider.autoDispose
    .family<SermonDetail, String>((ref, id) => ref.watch(repositoryProvider).sermonDetail(id));

/// A study's translations as the admin sees them, hidden ones included.
final adminTranslationsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, studyId) => ref.watch(repositoryProvider).translations(studyId));

/// Latest job per step, refreshed every two seconds while the page is open.
final sermonJobsProvider = StreamProvider.autoDispose.family<Map<String, Job>, String>((ref, sermonId) async* {
  final repo = ref.watch(repositoryProvider);
  while (true) {
    yield await repo.latestJobs(sermonId);
    await Future<void>.delayed(const Duration(seconds: 2));
  }
});

final churchSettingsProvider =
    FutureProvider<Map<String, dynamic>>((ref) => ref.watch(repositoryProvider).churchSettings());

final bibleVersionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) => ref.watch(repositoryProvider).bibleVersions());

final studyProvider = FutureProvider.autoDispose
    .family<PublicStudy?, String>((ref, slug) => ref.watch(repositoryProvider).studyBySlug(slug));

/// Day numbers read on this device. Members have no account, so progress stays local.
final readDaysProvider = FutureProvider.autoDispose.family<Set<int>, String>((ref, studyId) async {
  final prefs = await SharedPreferences.getInstance();
  return (prefs.getStringList('read:$studyId') ?? const []).map(int.parse).toSet();
});

Future<void> markDayRead(WidgetRef ref, String studyId, int day) async {
  final prefs = await SharedPreferences.getInstance();
  final days = {...?prefs.getStringList('read:$studyId'), '$day'}.toList()..sort();
  await prefs.setStringList('read:$studyId', days);
  ref.invalidate(readDaysProvider(studyId));
}
