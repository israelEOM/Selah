import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/l10n/app_localizations_es.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/data/repository.dart';
import 'package:selah/src/features/church/join_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef _Info = ({String churchName, String churchSlug, ChurchRole role});

class _FakeRepository implements SelahRepository {
  _FakeRepository(this.info, {this.acceptFails = false});

  final _Info? info;
  final bool acceptFails;
  final accepted = <String>[];

  @override
  Future<_Info?> inviteInfo(String token) async => info;

  @override
  Future<String> acceptInvite(String token) async {
    if (acceptFails) throw PostgrestException(message: 'invite_invalid');
    accepted.add(token);
    return 'vida-nueva';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _Info _editorInfo = (churchName: 'Vida Nueva', churchSlug: 'vida-nueva', role: ChurchRole.editor);

Future<_FakeRepository> _pump(
  WidgetTester tester, {
  _Info? info = _editorInfo,
  String? userId,
  bool acceptFails = false,
}) async {
  final fake = _FakeRepository(info, acceptFails: acceptFails);
  final router = GoRouter(initialLocation: '/join/t1', routes: [
    GoRoute(path: '/join/:token', builder: (_, s) => JoinPage(token: s.pathParameters['token']!)),
    GoRoute(path: '/login', builder: (_, s) => Text('LOGIN ${s.uri.queryParameters['next']}')),
    GoRoute(path: '/c/:church/admin', builder: (_, s) => Text('ADMIN ${s.pathParameters['church']}')),
    GoRoute(path: '/c/:church', builder: (_, s) => Text('CHURCH ${s.pathParameters['church']}')),
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

void main() {
  final es = AppLocalizationsEs();

  testWidgets('signed out sees the church and role and signs in to join', (tester) async {
    await _pump(tester);
    expect(find.text(es.joinChurchAs('Vida Nueva', es.roleEditor)), findsOneWidget);
    await tester.tap(find.text(es.signInToJoin));
    await tester.pumpAndSettle();
    expect(find.text('LOGIN /join/t1'), findsOneWidget);
  });

  testWidgets('signed in accepts and lands in the admin for an editor invite', (tester) async {
    final fake = await _pump(tester, userId: 'user-1');
    expect(fake.accepted, ['t1']);
    expect(find.text('ADMIN vida-nueva'), findsOneWidget);
  });

  testWidgets('signed in lands on the church for a member invite', (tester) async {
    await _pump(tester,
        userId: 'user-1', info: (churchName: 'Vida Nueva', churchSlug: 'vida-nueva', role: ChurchRole.member));
    expect(find.text('CHURCH vida-nueva'), findsOneWidget);
  });

  testWidgets('an unknown link is reported', (tester) async {
    final fake = await _pump(tester, info: null, userId: 'user-1');
    expect(find.text(es.inviteInvalid), findsOneWidget);
    expect(fake.accepted, isEmpty);
  });

  testWidgets('a link that stops working while joining is reported', (tester) async {
    await _pump(tester, userId: 'user-1', acceptFails: true);
    expect(find.text(es.inviteInvalid), findsOneWidget);
  });
}
