import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/data/repository.dart';
import 'package:selah/src/features/auth/login_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeRepository implements SelahRepository {
  final calls = <OAuthProvider>[];

  @override
  Future<void> signInWithProvider(OAuthProvider provider, {required String redirectTo}) async =>
      calls.add(provider);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeRepository> _pump(WidgetTester tester, {Uri? landing, String? userAgent}) async {
  final fake = _FakeRepository();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(fake),
      userIdProvider.overrideWith((ref) => Stream.value(null)),
      isAdminProvider.overrideWith((ref) async => false),
    ],
    child: MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LoginPage(landing: landing ?? Uri.parse('https://selah-226.pages.dev/login'), userAgent: userAgent ?? ''),
    ),
  ));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('shows the Google button', (tester) async {
    await _pump(tester);
    expect(find.text('Continuar con Google'), findsOneWidget);
  });

  testWidgets('Google button starts Google sign-in', (tester) async {
    final fake = await _pump(tester);
    await tester.tap(find.text('Continuar con Google'));
    await tester.pump();
    expect(fake.calls, [OAuthProvider.google]);
  });

  testWidgets('a second tap does nothing', (tester) async {
    final fake = await _pump(tester);
    await tester.tap(find.text('Continuar con Google'));
    await tester.pump();
    await tester.tap(find.text('Continuar con Google'), warnIfMissed: false);
    await tester.pump();
    expect(fake.calls, [OAuthProvider.google]);
  });

  testWidgets('cancelled return shows the cancel message', (tester) async {
    await _pump(tester, landing: Uri.parse('https://selah-226.pages.dev/login?error=access_denied'));
    expect(find.text('No se completó el inicio de sesión. Inténtalo de nuevo.'), findsOneWidget);
  });

  testWidgets('other provider error shows a generic message', (tester) async {
    await _pump(tester,
        landing: Uri.parse('https://selah-226.pages.dev/login#error=server_error&error_description=x'));
    expect(find.text('No fue posible iniciar sesión con esa cuenta. Inténtalo de nuevo o usa tu correo.'),
        findsOneWidget);
    expect(find.text('x'), findsNothing);
  });

  testWidgets('in-app browser hint', (tester) async {
    await _pump(tester, userAgent: 'Mozilla/5.0 (iPhone) Instagram 300.0');
    expect(find.text('Para entrar con Google, abre esta página en Safari o Chrome.'), findsOneWidget);
  });
}
