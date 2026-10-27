import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/data/repository.dart';
import 'package:selah/src/features/church/church_page.dart';

const _church = Church(id: 'A', slug: 'vida-nueva', name: 'Iglesia Vida Nueva');

class _FakeRepository implements SelahRepository {
  final joined = <String>[];
  bool failJoin = false;

  @override
  Future<void> joinChurch(String churchId) async {
    if (failJoin) throw Exception('nope');
    joined.add(churchId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeRepository> _pump(WidgetTester tester,
    {String? userId, ChurchRole? role, bool failJoin = false, bool roleLoading = false}) async {
  final fake = _FakeRepository()..failJoin = failJoin;
  final router = GoRouter(initialLocation: '/c/vida-nueva', routes: [
    GoRoute(path: '/c/vida-nueva', builder: (_, _) => const ChurchPage(church: _church)),
    GoRoute(path: '/c/vida-nueva/studies/:slug', builder: (_, s) => Text('STUDY ${s.pathParameters['slug']}')),
    GoRoute(path: '/c/vida-nueva/admin', builder: (_, _) => const Text('ADMIN')),
    GoRoute(path: '/login', builder: (_, s) => Text('LOGIN ${s.uri.queryParameters['next']}')),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(fake),
      userIdProvider.overrideWith((ref) => Stream.value(userId)),
      myChurchesProvider.overrideWith((ref) async => const []),
      churchRoleProvider('A').overrideWith((ref) => roleLoading ? Completer<ChurchRole?>().future : Future.value(role)),
      publishedStudiesProvider('A').overrideWith((ref) async => const [
            StudyCard(id: '1', slug: 'retiro-espiritual', title: 'La necesidad del retiro espiritual', numberOfDays: 3),
          ]),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  if (roleLoading) {
    await tester.pump(const Duration(milliseconds: 100));
  } else {
    await tester.pumpAndSettle();
  }
  return fake;
}

void main() {
  testWidgets('lists the studies and opens one', (tester) async {
    await _pump(tester);
    expect(find.text('Iglesia Vida Nueva'), findsOneWidget);
    expect(find.text('Gestionar'), findsNothing);
    await tester.tap(find.text('La necesidad del retiro espiritual'));
    await tester.pumpAndSettle();
    expect(find.text('STUDY retiro-espiritual'), findsOneWidget);
  });

  testWidgets('editors get a manage action', (tester) async {
    await _pump(tester, userId: 'u', role: ChurchRole.editor);
    await tester.tap(find.text('Gestionar'));
    await tester.pumpAndSettle();
    expect(find.text('ADMIN'), findsOneWidget);
  });

  testWidgets('a signed-in person without a role can follow', (tester) async {
    final fake = await _pump(tester, userId: 'u');
    await tester.tap(find.text('Seguir'));
    await tester.pumpAndSettle();
    expect(fake.joined, ['A']);
  });

  testWidgets('follow is not offered while the role is loading', (tester) async {
    await _pump(tester, userId: 'u', roleLoading: true);
    expect(find.text('Seguir'), findsNothing);
  });

  testWidgets('a failed follow shows an error', (tester) async {
    await _pump(tester, userId: 'u', failJoin: true);
    await tester.tap(find.text('Seguir'));
    await tester.pumpAndSettle();
    expect(find.text('No fue posible completar esta acción.'), findsOneWidget);
  });

  testWidgets('a visitor is not offered follow', (tester) async {
    await _pump(tester);
    expect(find.text('Seguir'), findsNothing);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
