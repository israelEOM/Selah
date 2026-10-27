import 'package:flutter/material.dart';
import 'package:selah/src/app/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/features/admin/admin_gate.dart';

const _church = Church(id: 'A', slug: 'vida-nueva', name: 'Iglesia Vida Nueva');
const _adminOnly = 'Esta sección es solo para quienes administran esta iglesia.';

Future<void> _pump(WidgetTester tester, ChurchRole? role, {ChurchRole minRole = ChurchRole.editor}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      userIdProvider.overrideWith((ref) => Stream.value(role == null ? null : 'user-1')),
      churchRoleProvider('A').overrideWith((ref) async => role),
    ],
    child: MaterialApp(
      theme: selahLightTheme(),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdminPage(church: _church, minRole: minRole, backTo: '/c/vida-nueva', children: const [Text('CONTENT')]),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an editor sees the content', (tester) async {
    await _pump(tester, ChurchRole.editor);
    expect(find.text('CONTENT'), findsOneWidget);
    expect(find.text(_adminOnly), findsNothing);
  });

  testWidgets('an owner sees the content', (tester) async {
    await _pump(tester, ChurchRole.owner);
    expect(find.text('CONTENT'), findsOneWidget);
  });

  testWidgets('a member sees the message', (tester) async {
    await _pump(tester, ChurchRole.member);
    expect(find.text('CONTENT'), findsNothing);
    expect(find.text(_adminOnly), findsOneWidget);
  });

  testWidgets('someone outside the church sees the message', (tester) async {
    await _pump(tester, null);
    expect(find.text('CONTENT'), findsNothing);
    expect(find.text(_adminOnly), findsOneWidget);
  });

  testWidgets('an owner-only screen shows the message to an editor', (tester) async {
    await _pump(tester, ChurchRole.editor, minRole: ChurchRole.owner);
    expect(find.text('CONTENT'), findsNothing);
    expect(find.text(_adminOnly), findsOneWidget);
  });

  testWidgets('signed-out Sign in keeps the deep link', (tester) async {
    final router = GoRouter(initialLocation: '/c/vida-nueva/admin/people', routes: [
      GoRoute(
          path: '/c/vida-nueva/admin/people',
          builder: (_, _) => const AdminPage(church: _church, backTo: '/c/vida-nueva', children: [Text('CONTENT')])),
      GoRoute(path: '/login', builder: (_, s) => Text('LOGIN ${s.uri.queryParameters['next']}')),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        userIdProvider.overrideWith((ref) => Stream.value(null)),
        churchRoleProvider('A').overrideWith((ref) async => null),
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
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('LOGIN /c/vida-nueva/admin/people'), findsOneWidget);
  });
}
