import 'package:flutter/material.dart';
import 'package:selah/src/app/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/app/app.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/data/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _vidaNueva = Church(id: 'A', slug: 'vida-nueva', name: 'Iglesia Vida Nueva');
const _otra = Church(id: 'B', slug: 'otra', name: 'Otra iglesia');

class _FakeRepository implements SelahRepository {
  @override
  Future<String?> legacyStudyChurch(String slug) async => slug == 'fe' ? 'vida-nueva' : null;

  @override
  Future<Church?> churchBySlug(String slug) async => const {'vida-nueva': _vidaNueva, 'otra': _otra}[slug];

  @override
  Future<PublicStudy?> studyBySlug(String churchId, String slug) async => null;

  @override
  Future<List<StudyCard>> publishedStudies(String churchId) async => const [];

  @override
  Future<List<Church>> publicChurches() async => const [];

  @override
  Future<List<SermonRow>> sermons(String churchId) async => const [];

  @override
  Future<ChurchRole?> roleIn(String churchId) async => churchId == 'A' ? ChurchRole.editor : ChurchRole.member;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<GoRouter> _pump(WidgetTester tester, String location, {List<Membership> churches = const []}) async {
  SharedPreferences.setMockInitialValues({});
  final router = createRouter(initialLocation: location);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(_FakeRepository()),
      userIdProvider.overrideWith((ref) => Stream.value(churches.isEmpty ? null : 'user-1')),
      myChurchesProvider.overrideWith((ref) async => churches),
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
  return router;
}

String _path(GoRouter router) => router.routerDelegate.currentConfiguration.uri.path;

void main() {
  testWidgets('an old reader link moves under its church', (tester) async {
    final router = await _pump(tester, '/studies/fe/day/2');
    expect(_path(router), '/c/vida-nueva/studies/fe/day/2');
  });

  testWidgets('an old study link moves under its church', (tester) async {
    final router = await _pump(tester, '/studies/fe');
    expect(_path(router), '/c/vida-nueva/studies/fe');
  });

  testWidgets('an old link to a study that no longer exists goes home', (tester) async {
    final router = await _pump(tester, '/studies/nada');
    expect(_path(router), '/');
  });

  testWidgets('an unknown church says so', (tester) async {
    await _pump(tester, '/c/nope');
    expect(find.text('No encontramos esta iglesia.'), findsOneWidget);
  });

  testWidgets('/admin opens the first church the person can edit', (tester) async {
    final router = await _pump(tester, '/admin', churches: const [
      Membership(church: _otra, role: ChurchRole.member),
      Membership(church: _vidaNueva, role: ChurchRole.editor),
    ]);
    expect(_path(router), '/c/vida-nueva/admin');
    expect(find.text('Predicaciones'), findsOneWidget);
  });

  testWidgets('/admin goes home for someone who edits no church', (tester) async {
    final router = await _pump(tester, '/admin', churches: const [
      Membership(church: _otra, role: ChurchRole.member),
    ]);
    expect(_path(router), '/');
  });
}
