import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/features/home/home_page.dart';

Future<void> _pump(WidgetTester tester, {String? userId, bool admin = false}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      userIdProvider.overrideWith((ref) => Stream.value(userId)),
      isAdminProvider.overrideWith((ref) async => admin),
      publishedStudiesProvider.overrideWith((ref) async => const []),
    ],
    child: MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomePage(),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a visitor sees sign in', (tester) async {
    await _pump(tester);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('a signed-in member sees sign out instead of sign in', (tester) async {
    await _pump(tester, userId: 'user-1');
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsNothing);
  });

  testWidgets('an admin sees the admin link', (tester) async {
    await _pump(tester, userId: 'user-1', admin: true);
    expect(find.text('Administrar'), findsOneWidget);
  });
}
