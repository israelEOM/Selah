import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:selah/src/app/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/features/home/church_picker_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _vida = Church(id: 'A', slug: 'vida-nueva', name: 'Iglesia Vida Nueva');
const _otra = Church(id: 'B', slug: 'otra', name: 'Otra Iglesia');

Future<void> _pump(WidgetTester tester, {String? userId, ChurchRole? role, bool loading = false}) async {
  SharedPreferences.setMockInitialValues({});
  final router = GoRouter(initialLocation: '/churches', routes: [
    GoRoute(path: '/', builder: (_, _) => const Text('HOME')),
    GoRoute(path: '/churches', builder: (_, _) => const ChurchPickerPage()),
    GoRoute(path: '/c/:church', builder: (_, s) => Text('CHURCH ${s.pathParameters['church']}')),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      userIdProvider.overrideWith((ref) => Stream.value(userId)),
      myChurchesProvider.overrideWith((ref) async => [if (role != null) Membership(church: _vida, role: role)]),
      publicChurchesProvider.overrideWith(
          (ref) => loading ? Completer<List<Church>>().future : Future.value(const [_vida, _otra])),
    ],
    child: MaterialApp.router(
      theme: selahLightTheme(),
      routerConfig: router,
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  if (loading) {
    await tester.pump(const Duration(milliseconds: 500));
  } else {
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('a visitor sees the public churches', (tester) async {
    await _pump(tester);
    expect(find.text('Elige tu iglesia'), findsWidgets);
    expect(find.text('TUS IGLESIAS'), findsNothing);
    expect(find.text('Iglesia Vida Nueva'), findsOneWidget);
    expect(find.text('Otra Iglesia'), findsOneWidget);
  });

  testWidgets('tapping a church remembers it and goes to Hoy', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Otra Iglesia'));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('church'), 'otra');
  });

  testWidgets('a signed-in member sees their churches with the role', (tester) async {
    await _pump(tester, userId: 'user-1', role: ChurchRole.editor);
    expect(find.text('TUS IGLESIAS'), findsOneWidget);
    expect(find.text('Editor'), findsOneWidget);
  });

  testWidgets('a member tapping a church they belong to chooses it and goes to Hoy', (tester) async {
    await _pump(tester, userId: 'user-1', role: ChurchRole.member);
    await tester.tap(find.text('Iglesia Vida Nueva').last);
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('church'), 'vida-nueva');
  });

  testWidgets('a member tapping a church they don\'t belong to opens its page', (tester) async {
    await _pump(tester, userId: 'user-1', role: ChurchRole.member);
    await tester.tap(find.text('Otra Iglesia'));
    await tester.pumpAndSettle();
    expect(find.text('CHURCH otra'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('church'), isNull);
  });

  testWidgets('signed in with no church, tapping a church still chooses it', (tester) async {
    await _pump(tester, userId: 'user-1');
    await tester.tap(find.text('Otra Iglesia'));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('church'), 'otra');
  });

  testWidgets('church picker shows skeletons while churches load', (tester) async {
    await _pump(tester, loading: true);
    expect(find.byType(Skeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('the church picker builds on iOS in portrait', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await _pump(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Iglesia Vida Nueva'), findsOneWidget);
      expect(find.text('Otra Iglesia'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
