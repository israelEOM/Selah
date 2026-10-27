import 'package:flutter/material.dart';
import 'package:selah/src/app/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/data/repository.dart';
import 'package:selah/src/features/auth/login_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeRepository implements SelahRepository {
  final calls = <OAuthProvider>[];
  final redirects = <String>[];

  @override
  Future<void> signInWithProvider(OAuthProvider provider, {required String redirectTo}) async {
    calls.add(provider);
    redirects.add(redirectTo);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeRepository> _pump(WidgetTester tester, {Uri? landing, String? userAgent}) async {
  final fake = _FakeRepository();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(fake),
      userIdProvider.overrideWith((ref) => Stream.value(null)),
      myChurchesProvider.overrideWith((ref) async => const []),
    ],
    child: MaterialApp(
      theme: selahLightTheme(),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LoginPage(landing: landing ?? Uri.parse('https://selah-226.pages.dev/login'), userAgent: userAgent ?? ''),
    ),
  ));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('shows the Google button', (tester) async {
    await _pump(tester);
    expect(find.text('Continuar con Google'), findsOneWidget);
  });

  testWidgets('Google button starts Google sign-in', (tester) async {
    final fake = await _pump(tester);
    await tester.tap(find.text('Continuar con Google'));
    await tester.pump();
    expect(fake.calls, [OAuthProvider.google]);
  });

  testWidgets('a second tap does nothing', (tester) async {
    final fake = await _pump(tester);
    await tester.tap(find.text('Continuar con Google'));
    await tester.pump();
    await tester.tap(find.text('Continuar con Google'), warnIfMissed: false);
    await tester.pump();
    expect(fake.calls, [OAuthProvider.google]);
  });

  testWidgets('cancelled return shows the cancel message', (tester) async {
    await _pump(tester, landing: Uri.parse('https://selah-226.pages.dev/login?error=access_denied'));
    expect(find.text('No se completó el inicio de sesión. Inténtalo de nuevo.'), findsOneWidget);
  });

  testWidgets('other provider error shows a generic message', (tester) async {
    await _pump(tester,
        landing: Uri.parse('https://selah-226.pages.dev/login#error=server_error&error_description=x'));
    expect(find.text('No fue posible iniciar sesión con esa cuenta. Inténtalo de nuevo o usa tu correo.'),
        findsOneWidget);
    expect(find.text('x'), findsNothing);
  });

  testWidgets('in-app browser hint', (tester) async {
    await _pump(tester, userAgent: 'Mozilla/5.0 (iPhone) Instagram 300.0');
    expect(find.text('Para entrar con Google, abre esta página en Safari o Chrome.'), findsOneWidget);
  });

  for (final c in [
    (name: 'to next', next: '?next=/join/abc', role: ChurchRole.member, expected: 'JOIN abc'),
    (name: 'to the admin of the one church they edit', next: '', role: ChurchRole.editor, expected: 'ADMIN vida-nueva'),
    (name: 'home when they only follow', next: '', role: ChurchRole.member, expected: 'HOME'),
    (name: 'home when next leaves the site', next: '?next=//evil.com', role: ChurchRole.member, expected: 'HOME'),
  ]) {
    testWidgets('someone signed in is sent ${c.name}', (tester) async {
      final router = GoRouter(initialLocation: '/login', routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('HOME')),
        GoRoute(path: '/join/:t', builder: (_, s) => Text('JOIN ${s.pathParameters['t']}')),
        GoRoute(path: '/c/:church/admin', builder: (_, s) => Text('ADMIN ${s.pathParameters['church']}')),
        GoRoute(
          path: '/login',
          builder: (_, _) =>
              LoginPage(landing: Uri.parse('https://selah-226.pages.dev/login${c.next}'), userAgent: ''),
        ),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(_FakeRepository()),
          userIdProvider.overrideWith((ref) => Stream.value('user-1')),
          myChurchesProvider.overrideWith((ref) async => [
                Membership(
                  church: const Church(id: 'A', slug: 'vida-nueva', name: 'Iglesia Vida Nueva'),
                  role: c.role,
                ),
              ]),
        ],
        child: MaterialApp.router(
      theme: selahLightTheme(),
          routerConfig: router,
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text(c.expected), findsOneWidget);
    });
  }

  testWidgets('next still works when the memberships fetch fails', (tester) async {
    final router = GoRouter(initialLocation: '/login', routes: [
      GoRoute(path: '/join/:t', builder: (_, s) => Text('JOIN ${s.pathParameters['t']}')),
      GoRoute(
        path: '/login',
        builder: (_, _) =>
            LoginPage(landing: Uri.parse('https://selah-226.pages.dev/login?next=/join/abc'), userAgent: ''),
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(_FakeRepository()),
        userIdProvider.overrideWith((ref) => Stream.value('user-1')),
        myChurchesProvider.overrideWith((ref) async => throw Exception('network')),
      ],
      child: MaterialApp.router(
      theme: selahLightTheme(),
        routerConfig: router,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('JOIN abc'), findsOneWidget);
  });

  testWidgets('Google sign-in carries next in the return url', (tester) async {
    final fake = await _pump(tester, landing: Uri.parse('https://selah-226.pages.dev/login?next=/join/abc'));
    await tester.tap(find.text('Continuar con Google'));
    await tester.pump();
    expect(fake.redirects, ['https://selah-226.pages.dev/login?next=%2Fjoin%2Fabc']);
  });

  testWidgets('signed in with no next and a failing churches fetch goes home', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const Text('HOME')),
      GoRoute(path: '/login', builder: (_, _) => LoginPage(landing: Uri.parse('https://x.test/login'), userAgent: '')),
    ], initialLocation: '/login');
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [
        repositoryProvider.overrideWithValue(_FakeRepository()),
        userIdProvider.overrideWith((ref) => Stream.value('user-1')),
        myChurchesProvider.overrideWith((ref) async => throw Exception('offline')),
      ],
      child: MaterialApp.router(
      theme: selahLightTheme(),
        routerConfig: router,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });
}
