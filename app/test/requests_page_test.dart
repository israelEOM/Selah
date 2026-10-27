import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/l10n/app_localizations_es.dart';
import 'package:selah/src/app/theme.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/data/repository.dart';
import 'package:selah/src/features/admin/requests_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeRepository implements SelahRepository {
  _FakeRepository(this.pending);
  List<ChurchRequest> pending;
  final decided = <(String, bool, String?)>[];
  String? failWith;

  @override
  Future<List<ChurchRequest>> pendingChurchRequests() async => pending;

  @override
  Future<void> decideChurchRequest(String id, {required bool approve, String? slug}) async {
    if (failWith != null) throw PostgrestException(message: failWith!);
    decided.add((id, approve, slug));
    pending = [for (final r in pending) if (r.id != id) r];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ChurchRequest _request(String id, String name) => ChurchRequest(
      id: id,
      churchName: name,
      note: 'Somos una iglesia pequeña',
      status: ChurchRequestStatus.pending,
      createdAt: DateTime(2026, 10, 27),
      requesterEmail: 'pastor@example.com',
    );

Future<_FakeRepository> _pump(WidgetTester tester, List<ChurchRequest> pending, {String? failWith, bool platformAdmin = true}) async {
  final fake = _FakeRepository(pending)..failWith = failWith;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(fake),
      userIdProvider.overrideWith((ref) => Stream.value('user-1')),
      isPlatformAdminProvider.overrideWith((ref) async => platformAdmin),
    ],
    child: MaterialApp(
      theme: selahLightTheme(),
      home: const RequestsPage(),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await tester.pumpAndSettle();
  return fake;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

void main() {
  final es = AppLocalizationsEs();
  Finder approve() => find.widgetWithText(FilledButton, es.approve);
  Finder reject() => find.widgetWithText(OutlinedButton, es.reject);

  testWidgets('lists pending requests with a suggested address', (tester) async {
    await _pump(tester, [_request('r1', 'Iglesia Vida Nueva')]);
    expect(find.text('Iglesia Vida Nueva'), findsOneWidget);
    expect(find.textContaining('pastor@example.com'), findsOneWidget);
    expect(find.text('Somos una iglesia pequeña'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'iglesia-vida-nueva'), findsOneWidget);
    expect(find.textContaining('/c/iglesia-vida-nueva'), findsOneWidget);
  });

  testWidgets('approve sends the edited slug', (tester) async {
    final fake = await _pump(tester, [_request('r1', 'Iglesia Vida Nueva')]);
    await tester.enterText(find.byType(TextFormField), 'vida-nueva');
    await _tap(tester, approve());
    expect(fake.decided, [('r1', true, 'vida-nueva')]);
    expect(find.text(es.churchCreated), findsOneWidget);
    expect(find.text(es.noPendingRequests), findsOneWidget);
  });

  testWidgets('editing one card leaves the others alone', (tester) async {
    await _pump(tester, [_request('r1', 'Iglesia Uno'), _request('r2', 'Iglesia Dos')]);
    await tester.enterText(find.byType(TextFormField).first, 'otra');
    await tester.pump();
    expect(find.widgetWithText(TextFormField, 'otra'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'iglesia-dos'), findsOneWidget);
  });

  testWidgets('a taken slug shows the message and keeps the request', (tester) async {
    final fake = await _pump(tester, [_request('r1', 'Iglesia Vida Nueva')], failWith: 'church_slug_taken');
    await _tap(tester, approve());
    expect(find.text(es.slugTaken), findsOneWidget);
    expect(find.text('Iglesia Vida Nueva'), findsOneWidget);
    expect(fake.decided, isEmpty);
  });

  testWidgets('an invalid slug is rejected before calling the database', (tester) async {
    final fake = await _pump(tester, [_request('r1', 'Iglesia Vida Nueva')]);
    await tester.enterText(find.byType(TextFormField), 'Bad Slug');
    await _tap(tester, approve());
    expect(fake.decided, isEmpty);
    expect(find.text(es.slugInvalid), findsOneWidget);
  });

  testWidgets('a request someone else resolved says so and refreshes', (tester) async {
    final fake = await _pump(tester, [_request('r1', 'Iglesia Vida Nueva')], failWith: 'request_not_pending');
    fake.pending = [];
    await _tap(tester, approve());
    expect(find.text(es.requestAlreadyDecided), findsOneWidget);
    expect(find.text(es.noPendingRequests), findsOneWidget);
  });

  testWidgets('reject sends approve: false', (tester) async {
    final fake = await _pump(tester, [_request('r1', 'Iglesia Vida Nueva')]);
    await _tap(tester, reject());
    expect(fake.decided.single.$1, 'r1');
    expect(fake.decided.single.$2, false);
    expect(find.text(es.requestRejectedNotice), findsOneWidget);
  });

  testWidgets('an empty list says so', (tester) async {
    await _pump(tester, const []);
    expect(find.text(es.noPendingRequests), findsOneWidget);
  });

  testWidgets('a non-admin is told it is not allowed', (tester) async {
    await _pump(tester, [_request('r1', 'Iglesia Vida Nueva')], platformAdmin: false);
    expect(find.text(es.createChurchAdminOnly), findsOneWidget);
    expect(find.text('Iglesia Vida Nueva'), findsNothing);
  });
}
