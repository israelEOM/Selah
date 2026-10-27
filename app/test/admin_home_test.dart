import 'package:flutter/material.dart';
import 'package:selah/src/app/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/l10n/app_localizations_es.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/data/repository.dart';
import 'package:selah/src/features/admin/admin_home_page.dart';

const _church = Church(id: 'A', slug: 'vida-nueva', name: 'Vida Nueva', monthlySermonLimit: 4);

class _FakeRepository implements SelahRepository {
  _FakeRepository(this.used);
  final int used;

  @override
  Future<int> sermonsThisMonth(String churchId) async => used;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(WidgetTester tester, int used) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(_FakeRepository(used)),
      userIdProvider.overrideWith((ref) => Stream.value('user-1')),
      churchRoleProvider('A').overrideWith((ref) async => ChurchRole.editor),
      sermonsProvider('A').overrideWith((ref) async => []),
    ],
    child: MaterialApp(
      theme: selahLightTheme(),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AdminHomePage(church: _church),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  final es = AppLocalizationsEs();

  testWidgets('shows usage and keeps Import enabled under the limit', (tester) async {
    await _pump(tester, 1);
    expect(find.text('1 de 4 este mes'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, es.importSermon));
    expect(button.onPressed, isNotNull);
    expect(find.text(es.monthlyLimitReached(4)), findsNothing);
  });

  testWidgets('disables Import and explains at the limit', (tester) async {
    await _pump(tester, 4);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, es.importSermon));
    expect(button.onPressed, isNull);
    expect(find.text(es.monthlyLimitReached(4)), findsOneWidget);
  });
}
