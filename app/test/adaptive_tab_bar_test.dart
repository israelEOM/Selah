import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/app/app.dart';
import 'package:selah/src/app/design/adaptive_tab_bar.dart';
import 'package:selah/src/app/theme.dart';
import 'package:selah/src/core/models.dart';
import 'package:selah/src/data/current_church.dart';
import 'package:selah/src/data/providers.dart';
import 'package:selah/src/data/repository.dart';
import 'package:selah/src/features/welcome/welcome_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _vida = Church(id: 'A', slug: 'vida-nueva', name: 'Iglesia Vida Nueva');

class _FakeRepository implements SelahRepository {
  @override
  Future<Church?> churchBySlug(String slug) async => slug == 'vida-nueva' ? _vida : null;

  @override
  Future<List<StudyCard>> publishedStudies(String churchId) async => const [];

  @override
  Future<List<Church>> publicChurches() async => const [_vida];

  @override
  Future<List<SermonRow>> sermons(String churchId) async => const [];

  @override
  Future<ChurchRole?> roleIn(String churchId) async => ChurchRole.editor;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _tabs = [
  SelahTab(
    label: 'Hoy',
    icon: Icons.wb_sunny_outlined,
    selectedIcon: Icons.wb_sunny,
    symbol: 'sun.max',
    selectedSymbol: 'sun.max.fill',
  ),
  SelahTab(
    label: 'Estudios',
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book,
    symbol: 'book',
    selectedSymbol: 'book.fill',
  ),
  SelahTab(
    label: 'Perfil',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    symbol: 'person',
    selectedSymbol: 'person.fill',
  ),
];

Future<void> _pumpBar(WidgetTester tester, {TargetPlatform? platform, ValueChanged<int>? onTap}) =>
    tester.pumpWidget(MaterialApp(
      theme: selahLightTheme().copyWith(platform: platform),
      home: Scaffold(
        bottomNavigationBar: AdaptiveTabBar(tabs: _tabs, currentIndex: 0, onTap: onTap ?? (_) {}),
      ),
    ));

/// The router as shell_test pumps it.
Future<void> _pumpRouter(WidgetTester tester, String location, {TargetPlatform? platform}) async {
  SharedPreferences.setMockInitialValues({});
  final router = createRouter(initialLocation: location);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(_FakeRepository()),
      userIdProvider.overrideWith((ref) => Stream.value('user-1')),
      myChurchesProvider.overrideWith((ref) async => const [Membership(church: _vida, role: ChurchRole.editor)]),
      isPlatformAdminProvider.overrideWith((ref) async => false),
      currentChurchProvider.overrideWith((ref) async => _vida),
      needsWelcomeProvider.overrideWith((ref) async => false),
    ],
    child: MaterialApp.router(
      theme: selahLightTheme().copyWith(platform: platform),
      routerConfig: router,
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await tester.pumpAndSettle();
}

/// A 1000×800 window.
void _wide(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('on iOS the tab bar is the frosted floating bar in tests', (tester) async {
    await _pumpBar(tester, platform: TargetPlatform.iOS);
    expect(find.byType(FrostedTabBar), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('on Android the tab bar is a Material NavigationBar', (tester) async {
    await _pumpBar(tester, platform: TargetPlatform.android);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(FrostedTabBar), findsNothing);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('tapping a tab plays a selection haptic and reports the index (${platform.name})', (tester) async {
      final haptics = <Object?>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
      int? tapped;
      await _pumpBar(tester, platform: platform, onTap: (i) => tapped = i);
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      expect(haptics, ['HapticFeedbackType.selectionClick']);
      expect(tapped, 2);
    });
  }

  testWidgets('the selected tab is marked selected for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpBar(tester, platform: TargetPlatform.iOS);
    expect(tester.getSemantics(find.text('Hoy')), isSemantics(isSelected: true, isButton: true));
    expect(tester.getSemantics(find.text('Perfil')), isSemantics(isSelected: false, isButton: true));
    semantics.dispose();
  });

  testWidgets('the frosted capsule moves to the tapped tab', (tester) async {
    var index = 0;
    await tester.pumpWidget(MaterialApp(
      theme: selahLightTheme().copyWith(platform: TargetPlatform.iOS),
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          bottomNavigationBar: FrostedTabBar(tabs: _tabs, currentIndex: index, onTap: (i) => setState(() => index = i)),
        ),
      ),
    ));
    final capsule = find.byKey(FrostedTabBar.capsuleKey);
    final before = tester.getCenter(capsule).dx;
    await tester.tap(find.text('Perfil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final midway = tester.getCenter(capsule).dx;
    await tester.pumpAndSettle();
    final after = tester.getCenter(capsule).dx;
    expect(midway, greaterThan(before));
    expect(midway, lessThan(after));
    expect((after - tester.getCenter(find.text('Perfil')).dx).abs(), lessThan(1));
  });

  testWidgets('a wide Android window shows a navigation rail', (tester) async {
    _wide(tester);
    await _pumpRouter(tester, '/profile', platform: TargetPlatform.android);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('a wide iPad window keeps the floating bar', (tester) async {
    _wide(tester);
    await _pumpRouter(tester, '/profile', platform: TargetPlatform.iOS);
    expect(find.byType(FrostedTabBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('the last item on a page scrolls clear of the floating bar', (tester) async {
    // A phone-sized window, so the page is taller than the screen and the list really has to scroll.
    tester.view.physicalSize = const Size(390, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pumpRouter(tester, '/profile', platform: TargetPlatform.iOS);
    final list = find.byType(CustomScrollView);
    // The page lays out every child, so "below the fold" means below the window, not unbuilt.
    expect(tester.getRect(find.text('Cerrar sesión')).top, greaterThan(480), reason: 'the last item starts below the fold');
    await tester.drag(list, const Offset(0, -3000));
    await tester.pumpAndSettle();
    final lastButton = find.widgetWithText(TextButton, 'Cerrar sesión');
    expect(lastButton, findsOneWidget);
    expect(tester.getRect(lastButton).bottom, lessThanOrEqualTo(tester.getRect(find.byType(FrostedTabBar)).top));
  });

  testWidgets('pages scroll under the floating bar on iOS', (tester) async {
    await _pumpRouter(tester, '/profile', platform: TargetPlatform.iOS);
    final list = tester.getRect(find.byType(CustomScrollView));
    expect(list.bottom, greaterThan(tester.getRect(find.byType(FrostedTabBar)).top));
  });
}
