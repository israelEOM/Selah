import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/app/app.dart';
import 'package:selah/src/features/admin/admin_home_page.dart';
import 'package:selah/src/features/profile/profile_page.dart';
import 'package:selah/src/l10n/locale.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _church = Church(id: 'A', slug: 'vida-nueva', name: 'Iglesia Vida Nueva');

Widget _app(Widget home, {List<Override> overrides = const [], bool admin = false}) => ProviderScope(
      overrides: [
        userIdProvider.overrideWith((ref) => Stream.value(admin ? 'admin-1' : null)),
        myChurchesProvider.overrideWith((ref) async => const []),
        churchRoleProvider('A').overrideWith((ref) async => admin ? ChurchRole.editor : null),
        publicChurchesProvider.overrideWith((ref) async => const []),
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
  testWidgets('starts in Spanish on an English phone when nothing is saved', (tester) async {
    tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(appLocaleProvider), const Locale('es'));
  });

  test('a saved choice wins over the default', () {
    final container = ProviderContainer(overrides: [savedLanguageProvider.overrideWithValue('pt')]);
    addTearDown(container.dispose);
    expect(container.read(appLocaleProvider), const Locale('pt'));
  });

  testWidgets('choosing English changes the interface and is remembered', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_app(
      const ProfilePage(),
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
      Builder(builder: (context) => inSpanish(context, const AdminHomePage(church: _church))),
      admin: true,
      overrides: [
        savedLanguageProvider.overrideWithValue('en'),
        sermonsProvider('A').overrideWith((ref) async => const []),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Predicaciones'), findsOneWidget);
    expect(find.text('ADMINISTRAR'), findsOneWidget);
    expect(find.text('MANAGE'), findsNothing);
    expect(find.text('Manage'), findsNothing);
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
