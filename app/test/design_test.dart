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
}
