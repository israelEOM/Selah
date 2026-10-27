import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/app/theme.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/data/repository.dart';
import 'package:selah/src/features/welcome/welcome_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _vida = Church(id: 'A', slug: 'vida-nueva', name: 'Iglesia Vida Nueva');

class _FakeRepository implements SelahRepository {
  final joined = <String>[];
  final requested = <(String, String?)>[];
  String? failWith;

  @override
  Future<void> joinChurch(String churchId) async => joined.add(churchId);

  @override
  Future<ChurchRequest> requestChurch(String name, String? note) async {
    if (failWith != null) throw PostgrestException(message: failWith!);
    requested.add((name, note));
    return ChurchRequest(
      id: 'r1',
      churchName: name,
      note: note,
      status: ChurchRequestStatus.pending,
      createdAt: DateTime(2026, 10, 27),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeRepository> _pump(WidgetTester tester, {String? failWith, String location = '/welcome'}) async {
  SharedPreferences.setMockInitialValues({});
  final fake = _FakeRepository()..failWith = failWith;
  final router = GoRouter(initialLocation: location, routes: [
    GoRoute(path: '/', builder: (_, _) => const Text('HOME')),
    GoRoute(path: '/welcome', builder: (_, s) => WelcomePage(step: s.uri.queryParameters['step'])),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(fake),
      userIdProvider.overrideWith((ref) => Stream.value('user-1')),
      myChurchesProvider.overrideWith((ref) async => const []),
      myChurchRequestProvider.overrideWith((ref) async => null),
      isPlatformAdminProvider.overrideWith((ref) async => false),
      publicChurchesProvider.overrideWith((ref) async => const [_vida]),
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
  return fake;
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<void> _sendRequest(WidgetTester tester) async {
  await _tap(tester, 'Soy pastor o líder: quiero traer mi iglesia a Selah');
  await tester.enterText(find.widgetWithText(TextFormField, 'Nombre de la iglesia'), '  Iglesia Roca  ');
  await _tap(tester, 'Enviar solicitud');
}

void main() {
  testWidgets('shows the question', (tester) async {
    await _pump(tester);
    expect(find.text('¿Cómo vas a usar Selah?'), findsOneWidget);
    expect(find.text('Soy miembro de una iglesia'), findsOneWidget);
  });

  testWidgets('choosing member and a church joins it and opens Today', (tester) async {
    final fake = await _pump(tester);
    await _tap(tester, 'Soy miembro de una iglesia');
    await _tap(tester, 'Iglesia Vida Nueva');
    expect(fake.joined, ['A']);
    expect((await SharedPreferences.getInstance()).getString('church'), 'vida-nueva');
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('the leader form sends a request and shows it was sent', (tester) async {
    final fake = await _pump(tester);
    await _sendRequest(tester);
    expect(fake.requested, [('Iglesia Roca', null)]);
    expect(find.text('Solicitud enviada. Te avisaremos aquí cuando esté aprobada.'), findsOneWidget);
    await _tap(tester, 'Mientras tanto, unirme a una iglesia');
    expect(find.text('Iglesia Vida Nueva'), findsOneWidget);
  });

  testWidgets('the leader form checks the name length', (tester) async {
    final fake = await _pump(tester);
    await _tap(tester, 'Soy pastor o líder: quiero traer mi iglesia a Selah');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre de la iglesia'), ' a ');
    await _tap(tester, 'Enviar solicitud');
    expect(fake.requested, isEmpty);
    expect(find.text('El nombre debe tener entre 2 y 80 caracteres.'), findsOneWidget);
  });

  testWidgets('a second request shows the pending message', (tester) async {
    await _pump(tester, failWith: 'request_pending_exists');
    await _sendRequest(tester);
    expect(find.text('Ya tienes una solicitud pendiente.'), findsOneWidget);
  });

  testWidgets('Ahora no remembers the skip', (tester) async {
    await _pump(tester);
    await _tap(tester, 'Ahora no');
    expect((await SharedPreferences.getInstance()).getBool('welcomeSkipped:user-1'), true);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('step=leader opens the form directly', (tester) async {
    await _pump(tester, location: '/welcome?step=leader');
    expect(find.text('Enviar solicitud'), findsOneWidget);
  });
}
