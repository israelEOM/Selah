import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/l10n/app_localizations_es.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/data/repository.dart';
import 'package:selah/src/features/church/create_church_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeRepository implements SelahRepository {
  final created = <(String, String)>[];
  String? failWith;

  @override
  Future<Church> createChurch(String name, String slug) async {
    if (failWith != null) throw PostgrestException(message: failWith!);
    created.add((name, slug));
    return Church(id: 'N', slug: slug, name: name);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeRepository> _pump(WidgetTester tester, {String? userId = 'user-1', String? failWith}) async {
  final fake = _FakeRepository()..failWith = failWith;
  final router = GoRouter(initialLocation: '/churches/new', routes: [
    GoRoute(path: '/churches/new', builder: (_, _) => const CreateChurchPage()),
    GoRoute(path: '/c/:church/admin/settings', builder: (_, s) => Text('SETTINGS ${s.pathParameters['church']}')),
    GoRoute(path: '/login', builder: (_, s) => Text('LOGIN ${s.uri.queryParameters['next']}')),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(fake),
      userIdProvider.overrideWith((ref) => Stream.value(userId)),
      myChurchesProvider.overrideWith((ref) async => const []),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await tester.pumpAndSettle();
  return fake;
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(FilledButton));
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

void main() {
  test('slugFromName strips accents and punctuation', () {
    expect(slugFromName('Iglesia Vida Nueva — São Paulo'), 'iglesia-vida-nueva-sao-paulo');
    expect(slugFromName('  Ñandú, Ação & Corazón!  '), 'nandu-acao-corazon');
    expect(slugFromName('a' * 60).length, 40);
  });

  testWidgets('signed out goes to login', (tester) async {
    await _pump(tester, userId: null);
    expect(find.text('LOGIN /churches/new'), findsOneWidget);
  });

  testWidgets('typing a name fills the slug until it is edited', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Iglesia X');
    await tester.pump();
    expect(find.widgetWithText(TextFormField, 'iglesia-x'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, 'mia');
    await tester.enterText(find.byType(TextFormField).first, 'Iglesia Y');
    await tester.pump();
    expect(find.widgetWithText(TextFormField, 'mia'), findsOneWidget);
  });

  testWidgets('submitting creates the church and opens its settings', (tester) async {
    final fake = await _pump(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Iglesia X');
    await _submit(tester);
    expect(fake.created, [('Iglesia X', 'iglesia-x')]);
    expect(find.text('SETTINGS iglesia-x'), findsOneWidget);
  });

  testWidgets('a taken slug is reported', (tester) async {
    await _pump(tester, failWith: 'church_slug_taken');
    await tester.enterText(find.byType(TextFormField).first, 'Iglesia X');
    await _submit(tester);
    expect(find.text(AppLocalizationsEs().slugTaken), findsOneWidget);
  });

  testWidgets('a bad slug is rejected before calling the database', (tester) async {
    final fake = await _pump(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Iglesia X');
    await tester.enterText(find.byType(TextFormField).last, 'Bad Slug');
    await _submit(tester);
    expect(fake.created, isEmpty);
    expect(find.text(AppLocalizationsEs().slugInvalid), findsOneWidget);
  });

  testWidgets('a one-letter name is rejected before calling the database', (tester) async {
    final fake = await _pump(tester);
    await tester.enterText(find.byType(TextFormField).first, ' X ');
    await tester.enterText(find.byType(TextFormField).last, 'valid-slug');
    await _submit(tester);
    expect(fake.created, isEmpty);
    expect(find.text(AppLocalizationsEs().churchNameInvalid), findsOneWidget);
  });
}
