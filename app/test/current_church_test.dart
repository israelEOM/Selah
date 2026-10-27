import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/current_church.dart';
import 'package:selah/src/data/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _a = Church(id: 'A', slug: 'a', name: 'Iglesia A');
const _b = Church(id: 'B', slug: 'b', name: 'Iglesia B');
const _c = Church(id: 'C', slug: 'c', name: 'Iglesia C');

ProviderContainer _container({String? saved, String? user, List<Church> mine = const []}) {
  final List<Override> overrides = [
    savedChurchProvider.overrideWithValue(saved),
    userIdProvider.overrideWith((ref) => Stream.value(user)),
    myChurchesProvider.overrideWith((ref) async => [for (final c in mine) Membership(church: c, role: ChurchRole.member)]),
    for (final c in [_a, _b, _c]) churchProvider(c.slug).overrideWith((ref) async => c),
    churchProvider('gone').overrideWith((ref) async => null),
  ];
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('signed out uses the saved church', () async {
    final container = _container(saved: 'c');
    expect(await _resolve(container), _c);
  });

  test('a member with no saved church gets their church', () async {
    final container = _container(user: 'u', mine: [_a, _b]);
    expect(await _resolve(container), _a);
  });

  test('a saved church that is one of mine wins over the first membership', () async {
    final container = _container(saved: 'b', user: 'u', mine: [_a, _b]);
    expect(await _resolve(container), _b);
  });

  test("a saved church I don't belong to loses to my membership", () async {
    final container = _container(saved: 'c', user: 'u', mine: [_a, _b]);
    expect(await _resolve(container), _a);
  });

  test('a signed-in user with no memberships uses the saved church', () async {
    final container = _container(saved: 'c', user: 'u');
    expect(await _resolve(container), _c);
  });

  test('a saved church that no longer exists falls back to my membership', () async {
    final container = _container(saved: 'gone', user: 'u', mine: [_a]);
    expect(await _resolve(container), _a);
  });

  test('nothing saved and no membership is null', () async {
    final container = _container();
    expect(await _resolve(container), isNull);
  });

  test('choose saves the slug', () async {
    final container = _container();
    await container.read(chosenChurchSlugProvider.notifier).choose('b');
    expect(container.read(chosenChurchSlugProvider), 'b');
    expect((await SharedPreferences.getInstance()).getString('church'), 'b');
    expect(await loadSavedChurch(), 'b');
  });
}

/// Listens so the provider stays alive while it resolves.
Future<Church?> _resolve(ProviderContainer container) {
  container.listen(currentChurchProvider, (_, _) {});
  return container.read(currentChurchProvider.future);
}
