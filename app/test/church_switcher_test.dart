import 'package:flutter/material.dart';
import 'package:selah/src/app/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/features/church/church_switcher.dart';

const _a = Church(id: 'A', slug: 'a', name: 'Iglesia A');
const _b = Church(id: 'B', slug: 'b', name: 'Iglesia B');

Future<void> _pump(WidgetTester tester, List<Membership> memberships, {bool admin = true, bool platformAdmin = true}) async {
  final router = GoRouter(initialLocation: '/start', routes: [
    GoRoute(
      path: '/start',
      builder: (_, _) => Scaffold(appBar: AppBar(actions: [ChurchSwitcher(current: _a, admin: admin)])),
    ),
    GoRoute(path: '/c/:slug', builder: (_, s) => Text('PUBLIC ${s.pathParameters['slug']}')),
    GoRoute(path: '/c/:slug/admin', builder: (_, s) => Text('ADMIN ${s.pathParameters['slug']}')),
    GoRoute(path: '/churches/new', builder: (_, _) => const Text('NEW')),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      myChurchesProvider.overrideWith((ref) async => memberships),
      isPlatformAdminProvider.overrideWith((ref) async => platformAdmin),
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
}

void main() {
  final two = [
    const Membership(church: _a, role: ChurchRole.owner),
    const Membership(church: _b, role: ChurchRole.member),
  ];

  testWidgets('picking B goes to its public page', (tester) async {
    await _pump(tester, two);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iglesia B').last);
    await tester.pumpAndSettle();
    expect(find.text('PUBLIC b'), findsOneWidget);
  });

  testWidgets('picking A (owner) goes to its admin page', (tester) async {
    await _pump(tester, two);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iglesia A').last);
    await tester.pumpAndSettle();
    expect(find.text('ADMIN a'), findsOneWidget);
  });

  testWidgets('non-admin pages go to the public page', (tester) async {
    await _pump(tester, two, admin: false);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iglesia A').last);
    await tester.pumpAndSettle();
    expect(find.text('PUBLIC a'), findsOneWidget);
  });

  testWidgets('offers to create a church', (tester) async {
    await _pump(tester, two);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear una iglesia'));
    await tester.pumpAndSettle();
    expect(find.text('NEW'), findsOneWidget);
  });

  testWidgets('only platform admins are offered to create a church', (tester) async {
    await _pump(tester, two, platformAdmin: false);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Iglesia B'), findsWidgets);
    expect(find.text('Crear una iglesia'), findsNothing);
  });

  testWidgets('hidden with one church', (tester) async {
    await _pump(tester, [const Membership(church: _a, role: ChurchRole.owner)]);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });

  testWidgets('hidden with no church', (tester) async {
    await _pump(tester, const []);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });
}
