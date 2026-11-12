import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/app/app.dart';
import 'package:selah/src/app/theme.dart';
import 'package:selah/src/core/config.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/current_church.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/data/repository.dart';
import 'package:selah/src/features/profile/profile_page.dart';
import 'package:selah/src/features/welcome/welcome_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pilot = Church(id: 'P', slug: 'selah', name: 'ICP Alcorcón');
const _other = Church(id: 'B', slug: 'otra', name: 'Otra iglesia');

class _FakeRepository implements SelahRepository {
  @override
  Future<Church?> churchBySlug(String slug) async => const {'selah': _pilot, 'otra': _other}[slug];

  @override
  Future<List<Church>> publicChurches() async => const [_pilot, _other];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(GoRouter router, List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        theme: selahLightTheme(),
        routerConfig: router,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );

void main() {
  setUp(() {
    pilotChurchSlug = 'selah';
    SharedPreferences.setMockInitialValues({'church': 'otra'});
  });
  tearDown(() => pilotChurchSlug = '');

  test('the current church is the pilot, whatever was chosen or joined', () async {
    final container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(_FakeRepository()),
      savedChurchProvider.overrideWithValue('otra'),
      userIdProvider.overrideWith((ref) => Stream.value('user-1')),
      myChurchesProvider.overrideWith((ref) async => const [Membership(church: _other, role: ChurchRole.member)]),
    ]);
    addTearDown(container.dispose);
    expect(container.read(chosenChurchSlugProvider), 'selah');
    expect((await container.read(currentChurchProvider.future))?.slug, 'selah');
  });

  test('a new account is never asked to join or bring a church', () async {
    final container = ProviderContainer(overrides: [
      userIdProvider.overrideWith((ref) => Stream.value('user-1')),
      myChurchesProvider.overrideWith((ref) async => const []),
      isPlatformAdminProvider.overrideWith((ref) async => false),
      myChurchRequestProvider.overrideWith((ref) async => null),
    ]);
    addTearDown(container.dispose);
    expect(await container.read(needsWelcomeProvider.future), isFalse);
  });

  for (final path in ['/churches', '/churches/new', '/welcome', '/requests']) {
    testWidgets('$path leads back to Today', (tester) async {
      final router = createRouter(initialLocation: path);
      await tester.pumpWidget(_app(router, [
        repositoryProvider.overrideWithValue(_FakeRepository()),
        userIdProvider.overrideWith((ref) => Stream.value(null)),
        myChurchesProvider.overrideWith((ref) async => const []),
        // Today's own content is covered elsewhere; here only the address matters.
        currentChurchProvider.overrideWith((ref) async => null),
      ]));
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/today');
    });
  }

  testWidgets('Perfil offers no other church: no change, join, bring or create', (tester) async {
    final router = GoRouter(initialLocation: '/profile', routes: [
      GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
    ]);
    await tester.pumpWidget(_app(router, [
      userIdProvider.overrideWith((ref) => Stream.value('user-1')),
      userNameProvider.overrideWith((ref) => 'Ana'),
      currentChurchProvider.overrideWith((ref) async => _pilot),
      churchRoleProvider('P').overrideWith((ref) async => null),
      isPlatformAdminProvider.overrideWith((ref) async => true),
      myChurchesProvider.overrideWith((ref) async => const []),
      myChurchRequestProvider.overrideWith((ref) async => null),
    ]));
    await tester.pumpAndSettle();
    final l = await AppLocalizations.delegate.load(const Locale('es'));
    expect(find.text('ICP Alcorcón'), findsOneWidget);
    for (final label in [l.changeChurch, l.pickChurch, l.joinAChurch, l.bringMyChurch, l.createChurch, l.churchRequests]) {
      expect(find.text(label), findsNothing, reason: label);
    }
  });
}
