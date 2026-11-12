import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:selah/src/app/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/l10n/app_localizations_es.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/data/repository.dart';
import 'package:selah/src/app/design/art.dart';
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

Future<void> _pump(WidgetTester tester, int used, {List<SermonRow> sermons = const [], bool reduce = false, bool settle = true}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(_FakeRepository(used)),
      userIdProvider.overrideWith((ref) => Stream.value('user-1')),
      churchRoleProvider('A').overrideWith((ref) async => ChurchRole.editor),
      sermonsProvider('A').overrideWith((ref) async => sermons),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduce), child: child!),
      theme: selahLightTheme(),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AdminHomePage(church: _church),
    ),
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
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

  testWidgets('the admin home builds on iOS in portrait', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await _pump(tester, 1);
      expect(tester.takeException(), isNull);
      expect(find.text('1 de 4 este mes'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  const generating = [SermonRow(id: 's1', title: 'Uno', studyStatus: 'generating')];

  testWidgets('the generating chip shimmers and stops with Reduce Motion', (tester) async {
    await _pump(tester, 1, sermons: generating, settle: false);
    expect(find.byKey(const ValueKey('shimmer')), findsOneWidget);
    // A repeating sweep never settles.
    await tester.pump(const Duration(seconds: 2));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, 1, sermons: generating, reduce: true);
    expect(find.byKey(const ValueKey('shimmer')), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('sermon rows show art and coloured status chips', (tester) async {
    await _pump(tester, 1, sermons: const [
      SermonRow(id: 's1', title: 'Uno', studyStatus: 'published'),
      SermonRow(id: 's2', title: 'Dos', studyStatus: 'review'),
    ]);
    expect(find.byType(SelahArt), findsNWidgets(2));
    expect(tester.getSize(find.byType(SelahArt).first), const Size(46, 46));
    final ctx = tester.element(find.text('Uno'));
    Color colourOf(String label) => tester.widget<Text>(find.text(label)).style!.color!;
    expect(colourOf(es.statusPublished.toUpperCase()), ctx.tones.done);
    expect(colourOf(es.statusReview.toUpperCase()), ctx.tones.accent);
  });

  testWidgets('the monthly bar fills from empty in terracotta', (tester) async {
    await _pump(tester, 2, settle: false);
    final bar = find.byKey(const ValueKey('usage-bar'));
    expect(tester.widget<LinearProgressIndicator>(bar).value, lessThan(0.5)); // still filling
    await tester.pumpAndSettle();
    final done = tester.widget<LinearProgressIndicator>(bar);
    expect(done.value, 0.5);
    expect(done.color, tester.element(bar).tones.accent);
  });

  testWidgets("a row shows its study's art, seeded by the study", (tester) async {
    await _pump(tester, 1, sermons: const [
      SermonRow(id: 's1', title: 'Uno', studyId: 'st1', artKey: 'dawn'),
    ]);
    final art = tester.widget<SelahArt>(find.byType(SelahArt));
    expect(art.artKey, 'dawn');
    expect(art.seed, 'st1');
  });
}
