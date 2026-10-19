import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/features/admin/admin_gate.dart';
import 'package:selah/src/features/home/home_page.dart';
import 'package:selah/src/l10n/locale.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget home, {List<Override> overrides = const [], bool admin = false}) => ProviderScope(
      overrides: [
        userIdProvider.overrideWith((ref) => Stream.value(admin ? 'admin-1' : null)),
        isAdminProvider.overrideWith((ref) async => admin),
        publishedStudiesProvider.overrideWith((ref) async => const []),
        ...overrides,
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          locale: ref.watch(appLocaleProvider),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );

void main() {
  test('languageFor maps device locales', () {
    expect(languageFor(const Locale('pt', 'PT')), 'pt');
    expect(languageFor(const Locale('pt', 'BR')), 'pt');
    expect(languageFor(const Locale('en', 'GB')), 'en');
    expect(languageFor(const Locale('fr')), 'es');
    expect(languageFor(const Locale('es', 'MX')), 'es');
  });

  testWidgets('choosing English changes the interface and is remembered', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_app(
      const HomePage(),
      overrides: [savedLanguageProvider.overrideWithValue('es')],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.translate));
    await tester.pumpAndSettle();
    expect(find.text('Español'), findsOneWidget);
    expect(find.text('Português'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('language'), 'en');
  });

  testWidgets('admin screens stay in Spanish', (tester) async {
    await tester.pumpWidget(_app(
      AdminPage(
        backTo: '/',
        children: [Builder(builder: (c) => Text(AppLocalizations.of(c)!.adminTitle))],
      ),
      admin: true,
      overrides: [savedLanguageProvider.overrideWithValue('en')],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Predicaciones'), findsOneWidget);
  });

  test('every key exists in every language', () {
    Set<String> keys(String code) =>
        (jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync()) as Map<String, dynamic>)
            .keys
            .where((k) => !k.startsWith('@'))
            .toSet();
    expect(keys('en'), keys('es'));
    expect(keys('pt'), keys('es'));
  });
}
