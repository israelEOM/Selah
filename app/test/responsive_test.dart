import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/app/theme.dart';

Future<void> pumpAt(WidgetTester tester, Size size, Widget child, {TargetPlatform platform = TargetPlatform.android}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = platform;
  await tester.pumpWidget(MaterialApp(
    theme: selahLightTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  ));
  debugDefaultTargetPlatformOverride = null;
}

Widget tiles(int n) => Material(
      child: CardGrid(children: [for (var i = 0; i < n; i++) SizedBox(key: ValueKey(i), height: 50)]),
    );

void main() {
  testWidgets('siteLayout is on at 1024 for Android and never for iOS', (tester) async {
    late bool result;
    final probe = Builder(builder: (context) {
      result = siteLayout(context);
      return const SizedBox();
    });
    await pumpAt(tester, const Size(1023, 800), probe);
    expect(result, isFalse);
    await pumpAt(tester, const Size(1024, 800), probe);
    expect(result, isTrue);
    await pumpAt(tester, const Size(1280, 800), probe, platform: TargetPlatform.iOS);
    expect(result, isFalse);
  });

  testWidgets('TwoColumn puts the side to the right of the main column', (tester) async {
    const main = ValueKey('main'), side = ValueKey('side');
    await pumpAt(
      tester,
      const Size(1280, 800),
      const TwoColumn(main: SizedBox(key: main, height: 40), side: SizedBox(key: side, height: 40)),
    );
    expect(tester.getTopLeft(find.byKey(side)).dx, greaterThan(tester.getTopRight(find.byKey(main)).dx));
    expect(tester.getSize(find.byKey(side)).width, 340);
  });

  testWidgets('CardGrid uses three columns at 1000 and one at 375', (tester) async {
    double dy(int i) => tester.getTopLeft(find.byKey(ValueKey(i))).dy;
    await pumpAt(tester, const Size(1000, 800), tiles(6));
    expect(dy(1), dy(0));
    expect(dy(2), dy(0));
    expect(dy(3), greaterThan(dy(0)));
    await pumpAt(tester, const Size(375, 800), tiles(6));
    expect({for (var i = 0; i < 6; i++) dy(i)}, hasLength(6));
  });

  testWidgets('a lone tile in CardGrid keeps its tile width', (tester) async {
    await pumpAt(tester, const Size(1000, 800), tiles(1));
    expect(tester.getSize(find.byKey(const ValueKey(0))).width, lessThan(400));
  });

  testWidgets('SelahPage on desktop has no app bar and shows the title in the content', (tester) async {
    await pumpAt(tester, const Size(1280, 800), const SelahPage(title: 'Hoje', backTo: '/', children: [Text('body')]));
    expect(find.byType(SliverAppBar), findsNothing);
    expect(find.text('Hoje'), findsOneWidget);
    final title = tester.widget<Text>(find.text('Hoje'));
    expect(title.style?.fontSize, selahLightTheme().textTheme.headlineMedium!.fontSize);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  testWidgets('SelahPage below desktop keeps the large app bar', (tester) async {
    await pumpAt(tester, const Size(390, 800), const SelahPage(title: 'Hoje', backTo: '/', children: [Text('body')]));
    expect(find.byType(SliverAppBar), findsOneWidget);
  });

  testWidgets('content is capped at 1200 on a 1920 window', (tester) async {
    const k = ValueKey('content');
    await pumpAt(tester, const Size(1920, 1080), const SelahPage(wide: true, children: [SizedBox(key: k, height: 10)]));
    final rect = tester.getRect(find.byKey(k));
    expect(rect.width, lessThanOrEqualTo(1200));
    expect((rect.center.dx - 960).abs(), lessThan(1));
  });
}
