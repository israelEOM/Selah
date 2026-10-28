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
}
