import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models.dart';
import '../../data/providers.dart';

String _skippedKey(String userId) => 'welcomeSkipped:$userId';

/// Whether to ask the signed-in person how they'll use Selah: not a platform admin, no church,
/// no request waiting, and they haven't said "Ahora no".
final needsWelcomeProvider = FutureProvider<bool>((ref) async {
  final userId = await ref.watch(userIdProvider.future);
  if (userId == null) return false;
  if ((await ref.watch(myChurchesProvider.future)).isNotEmpty) return false;
  if (await ref.watch(isPlatformAdminProvider.future)) return false;
  if ((await ref.watch(myChurchRequestProvider.future))?.status == ChurchRequestStatus.pending) return false;
  return (await SharedPreferences.getInstance()).getBool(_skippedKey(userId)) != true;
});

/// Remembers on this device that the signed-in person skipped the question.
Future<void> skipWelcome(WidgetRef ref) async {
  final userId = ref.read(userIdProvider).value;
  if (userId == null) return;
  await (await SharedPreferences.getInstance()).setBool(_skippedKey(userId), true);
  ref.invalidate(needsWelcomeProvider);
}

/// The accounts already shown the welcome question in this app session, so the tab shell asks at most once.
class WelcomeShown extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void add(String userId) => state = {...state, userId};
}

final welcomeShownProvider = NotifierProvider<WelcomeShown, Set<String>>(WelcomeShown.new);

/// Records that [userId] has seen the welcome question in this app session.
void markWelcomeShown(WidgetRef ref, String userId) => ref.read(welcomeShownProvider.notifier).add(userId);
