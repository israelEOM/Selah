import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/src/app/design/transitions.dart';
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
    final ios =
        builders[TargetPlatform.iOS]! as ReduceMotionPageTransitionsBuilder;
    final android =
        builders[TargetPlatform.android]! as ReduceMotionPageTransitionsBuilder;
    expect(ios.inner, isA<CupertinoPageTransitionsBuilder>());
    expect(android.inner, isA<PredictiveBackPageTransitionsBuilder>());
  });

  testWidgets('Reduce Motion turns page transitions into a fade', (
    tester,
  ) async {
    final builder =
        selahLightTheme().pageTransitionsTheme.builders[TargetPlatform.iOS]!;
    final route = PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const SizedBox(),
    );
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) => builder.buildTransitions<void>(
            route,
            context,
            const AlwaysStoppedAnimation(1),
            const AlwaysStoppedAnimation(0),
            const SizedBox(),
          ),
        ),
      ),
    );
    expect(find.byType(FadeTransition), findsOneWidget);
    expect(find.byType(CupertinoPageTransition), findsNothing);
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
