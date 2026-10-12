import 'package:flutter_riverpod/flutter_riverpod.dart';
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
