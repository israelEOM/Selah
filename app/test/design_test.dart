import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
