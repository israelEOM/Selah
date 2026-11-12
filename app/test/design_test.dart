import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/app/theme.dart';

void main() {
  Future<UiPlatform> platformUnder(
    WidgetTester tester,
    TargetPlatform target,
  ) async {
    debugDefaultTargetPlatformOverride = target;
    late UiPlatform result;
    await tester.pumpWidget(
      MaterialApp(
        theme: selahLightTheme(),
        home: Builder(
          builder: (context) {
            result = uiPlatformOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    debugDefaultTargetPlatformOverride = null;
    return result;
  }

  testWidgets('uiPlatformOf follows the target platform', (tester) async {
    expect(await platformUnder(tester, TargetPlatform.iOS), UiPlatform.ios);
    expect(
      await platformUnder(tester, TargetPlatform.android),
      UiPlatform.android,
    );
  });

  test('native glass is never used in tests', () {
    expect(nativeGlassAvailable, isFalse);
  });

  test('iOS pages slide and Android pages use predictive back', () {
    final builders = selahLightTheme().pageTransitionsTheme.builders;
    expect(
      builders[TargetPlatform.iOS],
      isA<CupertinoPageTransitionsBuilder>(),
    );
    expect(
      builders[TargetPlatform.android],
      isA<PredictiveBackPageTransitionsBuilder>(),
    );
  });

  testWidgets('Reduce Motion keeps the platform page transition', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: selahLightTheme().copyWith(platform: TargetPlatform.iOS),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const SizedBox(),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('next')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPageTransition), findsOneWidget);
  });

  testWidgets('tick, selection and success haptics call the platform', (
    tester,
  ) async {
    final calls = <Object?>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await SelahHaptics.tick();
    await SelahHaptics.selection();
    await SelahHaptics.success();
    expect(calls, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.mediumImpact',
    ]);
  });

  Widget host(Widget child, {bool reduce = false, TargetPlatform? platform}) => MaterialApp(
    theme: selahLightTheme().copyWith(platform: platform),
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
      child: c!,
    ),
    home: Scaffold(body: Center(child: child)),
  );

  double scaleOf(WidgetTester tester) {
    final t = tester.widget<Transform>(
      find.descendant(of: find.byType(Pressable), matching: find.byType(Transform)).first,
    );
    return t.transform.storage[0];
  }

  Widget box() => const SizedBox(width: 100, height: 50);

  testWidgets('Pressable shrinks while pressed and springs back', (tester) async {
    await tester.pumpWidget(host(Pressable(onPressed: () {}, child: box())));
    final g = await tester.startGesture(tester.getCenter(find.byType(Pressable)));
    await tester.pump(); // The first frame only starts the animation.
    await tester.pump(const Duration(milliseconds: 100));
    expect(scaleOf(tester), lessThan(1));
    await g.up();
    await tester.pumpAndSettle();
    expect(scaleOf(tester), 1);
  });

  testWidgets('Pressable does not shrink with Reduce Motion', (tester) async {
    await tester.pumpWidget(host(reduce: true, Pressable(onPressed: () {}, child: box())));
    final g = await tester.startGesture(tester.getCenter(find.byType(Pressable)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(scaleOf(tester), 1);
    await g.up();
    await tester.pumpAndSettle();
  });

  testWidgets('Pressable ignores a double tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(Pressable(onPressed: () => taps++, child: box())));
    await tester.tap(find.byType(Pressable));
    await tester.pump(); // The first frame only starts the debounce clock.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(Pressable));
    expect(taps, 1);
    await tester.pump(Motion.tapDebounce);
    await tester.tap(find.byType(Pressable));
    await tester.pumpAndSettle();
    expect(taps, 2);
  });

  testWidgets('SelahRow shows its label, detail and a chevron by default', (tester) async {
    await tester.pumpWidget(host(SelahRow(label: 'Reading', detail: 'John 3', onOpen: () {})));
    expect(find.text('Reading'), findsOneWidget);
    expect(find.text('John 3'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('SelahRow uses the iOS chevron on iOS', (tester) async {
    await tester.pumpWidget(host(platform: TargetPlatform.iOS, SelahRow(label: 'Reading', onOpen: () {})));
    expect(find.byIcon(CupertinoIcons.chevron_forward), findsOneWidget);
  });

  testWidgets('HeroCard shows its badge after it is set', (tester) async {
    await tester.pumpWidget(host(const HeroCard(quote: 'Q')));
    expect(find.text('Hecho por hoy'), findsNothing);
    await tester.pumpWidget(host(const HeroCard(quote: 'Q', badge: 'Hecho por hoy')));
    await tester.pumpAndSettle();
    expect(find.text('Hecho por hoy'), findsOneWidget);
  });

  const longQuote = 'A long quote that runs the whole width of the card and wraps onto a second and a third line.';

  testWidgets('HeroCard text runs the full width over its art', (tester) async {
    await tester.pumpWidget(host(const SizedBox(
      width: 360,
      child: HeroCard(title: 'A title', quote: longQuote, art: ColoredBox(color: Colors.red)),
    )));
    final card = tester.getRect(find.byType(HeroCard));
    expect(tester.getRect(find.text(longQuote)).right, closeTo(card.right - 22, 0.5));
  });

  testWidgets('HeroCard art fills the right of the card and fades in from its left edge', (tester) async {
    await tester.pumpWidget(host(const SizedBox(
      width: 360,
      child: HeroCard(title: 'A title', art: ColoredBox(color: Colors.red)),
    )));
    final card = tester.getRect(find.byType(HeroCard));
    final art = tester.getRect(find.byKey(const ValueKey('hero-art')));
    expect(art.right, card.right);
    expect(art.height, card.height);
    expect(art.width, closeTo(card.width * 0.6, 0.5));
    final mask = tester.widget<ShaderMask>(find.byKey(const ValueKey('hero-art')));
    expect(mask.blendMode, BlendMode.dstIn);
  });

  testWidgets('HeroCard without art gives its text the full width', (tester) async {
    await tester.pumpWidget(host(const SizedBox(width: 360, child: HeroCard(quote: longQuote))));
    final card = tester.getRect(find.byType(HeroCard));
    expect(tester.getRect(find.text(longQuote)).right, closeTo(card.right - 22, 0.5));
  });

  testWidgets('Entrance shows its child immediately with Reduce Motion', (tester) async {
    await tester.pumpWidget(host(reduce: true, const Entrance(index: 3, child: Text('hi'))));
    expect(tester.widget<FadeTransition>(find.byType(FadeTransition).last).opacity.value, 1);
  });

  testWidgets('Entrance fades in from zero without Reduce Motion', (tester) async {
    await tester.pumpWidget(host(const Entrance(index: 0, child: Text('hi'))));
    expect(tester.widget<FadeTransition>(find.byType(FadeTransition).last).opacity.value, 0);
    await tester.pumpAndSettle();
    expect(tester.widget<FadeTransition>(find.byType(FadeTransition).last).opacity.value, 1);
  });

  testWidgets('Entrance caps its stagger, so a late item waits no longer than the seventh', (tester) async {
    double opacity() => tester.widget<FadeTransition>(find.byType(FadeTransition).last).opacity.value;
    await tester.pumpWidget(host(const Entrance(index: 30, child: Text('hi'))));
    await tester.pump(); // The first frame only starts the animation.
    await tester.pump(Motion.staggerStep * 6 + Motion.medium);
    expect(opacity(), 1);
  });

  testWidgets('DayHero flies its child, not a second Hero with the same tag', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        theme: selahLightTheme(),
        home: const Scaffold(body: DayHero(tag: 'day', child: SizedBox(width: 100, height: 50, child: Text('card')))),
      ),
    );
    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: DayHero(tag: 'day', child: SizedBox(width: 300, height: 90, child: Text('page')))),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final shuttle = find.byType(OverflowBox);
    expect(shuttle, findsOneWidget, reason: 'the hero is mid-flight');
    expect(find.descendant(of: shuttle, matching: find.byType(Hero)), findsNothing);
    expect(find.descendant(of: shuttle, matching: find.text('page')), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('SkeletonList with a hero draws rows + 1 blocks', (tester) async {
    await tester.pumpWidget(host(reduce: true, const SkeletonList(rows: 3, hero: true)));
    expect(find.byType(Skeleton), findsNWidgets(4));
  });

  testWidgets('Pressable keeps its tap guard under Reduce Motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    var taps = 0;
    await tester.pumpWidget(host(reduce: true, Pressable(onPressed: () => taps++, child: box())));
    await tester.tap(find.byType(Pressable));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(Pressable));
    expect(taps, 1);
    await tester.pump(Motion.tapDebounce);
    await tester.tap(find.byType(Pressable));
    expect(taps, 2);
  });

  testWidgets('SelahRow builds on iOS without a Material ancestor', (tester) async {
    await tester.pumpWidget(
      Theme(
        data: selahLightTheme().copyWith(platform: TargetPlatform.iOS),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: SelahRow(label: 'Reading', onOpen: () {}),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Reading'), findsOneWidget);
  });

  testWidgets('SelahRow can be focused with Tab and opened with Enter on Android', (tester) async {
    var opens = 0;
    await tester.pumpWidget(host(platform: TargetPlatform.android, SelahRow(label: 'Reading', onOpen: () => opens++)));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(opens, 1);
    await tester.pump(Motion.tapDebounce);
  });

  testWidgets('Pressable can be focused with Tab and activated with Enter on iOS', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(platform: TargetPlatform.iOS, Pressable(onPressed: () => taps++, child: box())));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
    await tester.pump(Motion.tapDebounce);
  });

  testWidgets('Pressable springs back once a scroll starts under the finger', (tester) async {
    await tester.pumpWidget(
      host(
        SizedBox(
          height: 400,
          child: ListView(
            children: [
              Pressable(onPressed: () {}, child: const SizedBox(height: 120)),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
    final g = await tester.startGesture(tester.getCenter(find.byType(Pressable)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(scaleOf(tester), lessThan(1));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(0, -10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(scaleOf(tester), 1, reason: 'the finger is still down, but the press became a scroll');
    await g.up();
    await tester.pumpAndSettle();
  });

  Widget pageApp(Widget home, {GoRouter? router}) {
    final theme = selahLightTheme();
    if (router != null) {
      return MaterialApp.router(
        theme: theme,
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      );
    }
    return MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
  }

  testWidgets('SelahPage on iOS uses a large collapsing title', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(pageApp(const SelahPage(title: 'Today', children: [Text('body')])));
      expect(find.byType(CupertinoSliverNavigationBar), findsOneWidget);
      expect(find.text('Today'), findsWidgets);
      expect(find.text('body'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('SelahPage with no title builds on iOS', (tester) async {
    // Portrait: the sliver bar only builds its large title there.
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(pageApp(const SelahPage(backTo: '/', actions: [Icon(Icons.language)], children: [Text('body')])));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('body'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.byIcon(Icons.language), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a lazy SelahPage builds only the children on screen', (tester) async {
    await tester.pumpWidget(
      pageApp(
        SelahPage(
          title: 'Long',
          lazy: true,
          children: [for (var i = 0; i < 200; i++) SizedBox(height: 50, child: Text('item $i'))],
        ),
      ),
    );
    expect(find.text('item 0'), findsOneWidget);
    expect(find.text('item 150', skipOffstage: false), findsNothing);
    await tester.scrollUntilVisible(find.text('item 150'), 500, scrollable: find.byType(Scrollable).first);
    expect(find.text('item 150'), findsOneWidget);
  });

  testWidgets('a lazy SelahPage keeps the body centred at its max width', (tester) async {
    // A tablet width: the desktop website layout is covered in responsive_test.dart.
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      pageApp(SelahPage(title: 'Wide', lazy: true, children: const [SizedBox(height: 50, child: Text('item'))])),
    );
    final row = tester.getRect(find.ancestor(of: find.text('item'), matching: find.byType(SizedBox)).first);
    expect(row.width, 760 - 2 * (Space.xl - 4));
    expect(row.center.dx, 500);
  });

  /// The opacity [Entrance] gives [label], or 1 when it has none.
  double arrival(WidgetTester tester, String label) {
    final entrance = find.ancestor(of: find.text(label), matching: find.byType(Entrance));
    if (entrance.evaluate().isEmpty) return 1;
    return tester.widget<FadeTransition>(find.descendant(of: entrance.first, matching: find.byType(FadeTransition)).first).opacity.value;
  }

  testWidgets('SelahPage children fade in staggered', (tester) async {
    await tester.pumpWidget(pageApp(const SelahPage(title: 'T', children: [Text('first'), SizedBox(height: 8), Text('second')])));
    await tester.pump(const Duration(milliseconds: 50));
    expect(arrival(tester, 'first'), lessThan(1));
    expect(arrival(tester, 'second'), lessThan(arrival(tester, 'first')), reason: 'each block starts a little later');
    await tester.pumpAndSettle();
    expect(arrival(tester, 'first'), 1);
    expect(arrival(tester, 'second'), 1);
  });

  testWidgets('SelahPage children are shown at once with Reduce Motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(pageApp(const SelahPage(title: 'T', children: [Text('first'), Text('second')])));
    await tester.pump();
    expect(arrival(tester, 'first'), 1);
    expect(arrival(tester, 'second'), 1);
  });

  testWidgets('SelahPage leaves out arrival when asked, for lazy lists and for NoArrive children', (tester) async {
    await tester.pumpWidget(pageApp(const SelahPage(title: 'T', arrive: false, children: [Text('off')])));
    expect(find.ancestor(of: find.text('off'), matching: find.byType(Entrance)), findsNothing);
    await tester.pumpWidget(pageApp(const SelahPage(title: 'T', lazy: true, children: [Text('lazy')])));
    expect(find.ancestor(of: find.text('lazy'), matching: find.byType(Entrance)), findsNothing);
    await tester.pumpWidget(pageApp(const SelahPage(title: 'T', children: [NoArrive(child: Text('own')), Text('rest')])));
    expect(find.ancestor(of: find.text('own'), matching: find.byType(Entrance)), findsNothing);
    expect(find.ancestor(of: find.text('rest'), matching: find.byType(Entrance)), findsOneWidget);
    await tester.pumpAndSettle();
  });

  Widget switcherHost(ValueNotifier<bool> loading, {bool reduce = false}) => host(
        reduce: reduce,
        SizedBox(
          width: 300,
          child: ValueListenableBuilder<bool>(
            valueListenable: loading,
            builder: (context, value, _) =>
                ContentSwitcher(child: value ? const SkeletonList(rows: 2) : const Text('content')),
          ),
        ),
      );

  testWidgets('ContentSwitcher crossfades a skeleton into content', (tester) async {
    final loading = ValueNotifier(true);
    await tester.pumpWidget(switcherHost(loading));
    expect(find.byType(SkeletonList), findsOneWidget);
    loading.value = false;
    await tester.pump();
    await tester.pump(Motion.medium ~/ 2);
    // Halfway: both are on screen, the content partly faded in.
    expect(find.byType(SkeletonList), findsOneWidget);
    final fade = tester.widget<FadeTransition>(
      find.ancestor(of: find.text('content'), matching: find.byType(FadeTransition)).first,
    );
    expect(fade.opacity.value, inExclusiveRange(0, 1));
    expect(
      tester.widget<HeroMode>(find.ancestor(of: find.byType(SkeletonList), matching: find.byType(HeroMode)).first).enabled,
      isFalse,
      reason: 'the outgoing copy leaves its heroes behind',
    );
    await tester.pumpAndSettle();
    expect(find.byType(SkeletonList), findsNothing);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('ContentSwitcher swaps at once with Reduce Motion', (tester) async {
    final loading = ValueNotifier(true);
    await tester.pumpWidget(switcherHost(loading, reduce: true));
    loading.value = false;
    await tester.pump();
    await tester.pump();
    expect(find.byType(SkeletonList), findsNothing);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('SelahPage on Android uses a large Material app bar', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(pageApp(const SelahPage(title: 'Today', children: [Text('body')])));
      expect(find.byType(SliverAppBar), findsOneWidget);
      expect(find.byType(CupertinoSliverNavigationBar), findsNothing);
      expect(find.text('Today'), findsWidgets);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  for (final target in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('SelahPage back pops when it can and goes to backTo when it cannot ($target)', (tester) async {
      debugDefaultTargetPlatformOverride = target;
      try {
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const SelahPage(title: 'Home', children: [Text('home body')]),
            ),
            GoRoute(
              path: '/detail',
              builder: (_, _) => const SelahPage(title: 'Detail', backTo: '/', children: [Text('detail body')]),
            ),
          ],
        );
        await tester.pumpWidget(pageApp(const SizedBox(), router: router));
        router.push('/detail');
        await tester.pumpAndSettle();
        expect(find.text('detail body'), findsOneWidget);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(find.text('home body'), findsOneWidget);
        expect(find.text('detail body'), findsNothing);

        router.go('/detail');
        await tester.pumpAndSettle();
        expect(find.text('detail body'), findsOneWidget);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(find.text('home body'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('SelahPage pull to refresh calls onRefresh ($target)', (tester) async {
      debugDefaultTargetPlatformOverride = target;
      try {
        var calls = 0;
        await tester.pumpWidget(
          pageApp(SelahPage(title: 'Today', onRefresh: () async => calls++, children: const [Text('body')])),
        );
        await tester.fling(find.text('body'), const Offset(0, 400), 1000);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(calls, 1);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('AdaptiveSegmented picks the platform control and reports changes', (tester) async {
    for (final target in [TargetPlatform.iOS, TargetPlatform.android]) {
      debugDefaultTargetPlatformOverride = target;
      try {
        String? picked;
        await tester.pumpWidget(
          pageApp(
            Scaffold(
              body: Center(
                child: AdaptiveSegmented<String>(
                  segments: const {'a': 'Alpha', 'b': 'Beta'},
                  selected: 'a',
                  onChanged: (v) => picked = v,
                ),
              ),
            ),
          ),
        );
        expect(
          find.byType(target == TargetPlatform.iOS ? CupertinoSlidingSegmentedControl<String> : SegmentedButton<String>),
          findsOneWidget,
        );
        await tester.tap(find.text('Beta'));
        await tester.pumpAndSettle();
        expect(picked, 'b');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }
  });

  testWidgets('SelahPage on iOS draws the refresh spinner below the nav bar', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final done = Completer<void>();
      await tester.pumpWidget(
        pageApp(SelahPage(title: 'Today', onRefresh: () => done.future, children: const [Text('body')])),
      );
      final gesture = await tester.startGesture(tester.getCenter(find.text('body')));
      await gesture.moveBy(const Offset(0, 120));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 120));
      await tester.pump();
      // The bar is a sliver, so read its extent rather than a box rect. It is pinned at the top.
      final barBottom = tester.renderObject<RenderSliver>(find.byType(CupertinoSliverNavigationBar)).geometry!.paintExtent;
      final spinner = tester.getRect(find.byType(CupertinoActivityIndicator));
      expect(spinner.top, greaterThanOrEqualTo(barBottom));
      await gesture.up();
      done.complete();
      await tester.pump(const Duration(seconds: 2));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('SelahPage navigation bars do not share a hero tag on iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const IndexedStack(
              children: [
                SelahPage(title: 'One', children: [Text('one body')]),
                SelahPage(title: 'Two', children: [Text('two body')]),
              ],
            ),
          ),
          GoRoute(
            path: '/third',
            builder: (_, _) => const SelahPage(title: 'Third', backTo: '/', children: [Text('third body')]),
          ),
        ],
      );
      await tester.pumpWidget(pageApp(const SizedBox(), router: router));
      router.push('/third');
      await tester.pumpAndSettle();
      expect(find.text('third body'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('screen sizes switch at 600 and 1024', () {
    expect(screenSizeFor(375), ScreenSize.phone);
    expect(screenSizeFor(599), ScreenSize.phone);
    expect(screenSizeFor(600), ScreenSize.tablet);
    expect(screenSizeFor(1023), ScreenSize.tablet);
    expect(screenSizeFor(1024), ScreenSize.desktop);
    expect(screenSizeFor(1920), ScreenSize.desktop);
  });

  Future<double> bottomPaddingWithInset(WidgetTester tester, double inset) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: selahLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(padding: EdgeInsets.only(bottom: inset)),
            child: const SelahPage(title: 'Hoje', children: [SizedBox(height: 10)]),
          ),
        ),
      ),
    );
    return tester.widget<SliverPadding>(find.byType(SliverPadding).last).padding.resolve(TextDirection.ltr).bottom;
  }

  testWidgets('bottom gap under the tab bar is small', (tester) async {
    // Under the shell, the bottom inset already includes the tab bar's height.
    expect(await bottomPaddingWithInset(tester, 90), 90 + Layout.bottomGap);
  });

  testWidgets('bottom gap without a tab bar still clears the safe area', (tester) async {
    expect(await bottomPaddingWithInset(tester, 34), 34 + Layout.bottomGap);
  });
}
