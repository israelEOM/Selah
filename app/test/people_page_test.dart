import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/l10n/app_localizations_es.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/data/repository.dart';
import 'package:selah/src/features/admin/people_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _church = Church(id: 'A', slug: 'vida-nueva', name: 'Iglesia Vida Nueva');

class _FakeRepository implements SelahRepository {
  final calls = <String>[];
  String? failRoleWith;
  List<Map<String, dynamic>> inviteRows = [
    {'token': 't1', 'church_id': 'A', 'role': 'editor', 'revoked_at': null},
  ];

  @override
  Future<List<Map<String, dynamic>>> invites(String churchId) async => inviteRows;

  @override
  Future<String> createInvite(String churchId, ChurchRole role) async {
    calls.add('create:${role.name}');
    return 't2';
  }

  @override
  Future<void> revokeInvite(String token) async {
    calls.add('revoke:$token');
    inviteRows = [];
  }

  @override
  Future<List<Person>> people(String churchId) async => const [
        Person(userId: 'u1', name: 'Ana', email: 'ana@x.org', role: ChurchRole.owner),
        Person(userId: 'u2', name: null, email: 'beto@x.org', role: ChurchRole.editor),
      ];

  @override
  Future<void> setMemberRole(String churchId, String userId, ChurchRole role) async {
    if (failRoleWith != null) throw PostgrestException(message: failRoleWith!);
    calls.add('role:$churchId:$userId:${role.name}');
  }

  @override
  Future<void> removeMember(String churchId, String userId) async => calls.add('remove:$userId');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeRepository> _pump(WidgetTester tester, {ChurchRole role = ChurchRole.owner, String? failRoleWith}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = _FakeRepository()..failRoleWith = failRoleWith;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(fake),
      userIdProvider.overrideWith((ref) => Stream.value('user-1')),
      churchRoleProvider('A').overrideWith((ref) async => role),
    ],
    child: MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const PeoplePage(church: _church),
    ),
  ));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  final es = AppLocalizationsEs();

  testWidgets('shows the active editor link and offers to create the member link', (tester) async {
    await _pump(tester);
    expect(find.textContaining('/join/t1'), findsOneWidget);
    expect(find.text(es.revokeLink), findsOneWidget);
    expect(find.text(es.createLink), findsOneWidget);
  });

  testWidgets('revoking calls revokeInvite and offers a new link', (tester) async {
    final fake = await _pump(tester);
    await tester.tap(find.text(es.revokeLink));
    await tester.pumpAndSettle();
    expect(fake.calls, ['revoke:t1']);
    expect(find.textContaining('/join/t1'), findsNothing);
    expect(find.text(es.createLink), findsNWidgets(2));
  });

  testWidgets('creating a link calls createInvite for that role', (tester) async {
    final fake = await _pump(tester);
    await tester.tap(find.text(es.createLink));
    await tester.pumpAndSettle();
    expect(fake.calls, ['create:member']);
  });

  testWidgets('changing a role calls setMemberRole', (tester) async {
    final fake = await _pump(tester);
    await tester.tap(find.byType(DropdownButton<ChurchRole>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(es.roleOwner).last);
    await tester.pumpAndSettle();
    expect(fake.calls, ['role:A:u2:owner']);
  });

  testWidgets('removing a person calls removeMember', (tester) async {
    final fake = await _pump(tester);
    await tester.tap(find.text(es.removePerson).last);
    await tester.pumpAndSettle();
    expect(fake.calls, ['remove:u2']);
  });

  testWidgets('last_owner is explained', (tester) async {
    await _pump(tester, failRoleWith: 'last_owner');
    await tester.tap(find.byType(DropdownButton<ChurchRole>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(es.roleMember).last);
    await tester.pumpAndSettle();
    expect(find.text(es.lastOwner), findsOneWidget);
  });

  testWidgets('an editor is told this is for owners', (tester) async {
    await _pump(tester, role: ChurchRole.editor);
    expect(find.text(es.churchAdminOnly), findsOneWidget);
    expect(find.text(es.inviteLinks), findsNothing);
  });
}
