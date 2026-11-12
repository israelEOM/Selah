import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/src/app/theme.dart';
import 'package:selah/src/features/admin/admin_motion.dart';

void main() {
  Widget host({required bool reduce}) => MaterialApp(
        theme: selahLightTheme(),
        builder: (context, child) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduce), child: child!),
        home: const Scaffold(body: Center(child: Shimmer(child: Text('Generando', style: TextStyle(color: Colors.brown))))),
      );

  testWidgets('the shimmer keeps the text colour and only sweeps its opacity', (tester) async {
    await tester.pumpWidget(host(reduce: false));
    await tester.pump(const Duration(milliseconds: 400));
    final mask = tester.widget<ShaderMask>(find.byType(ShaderMask));
    // dstIn keeps the child's own colours and takes only the band's alpha; srcIn painted the text white.
    expect(mask.blendMode, BlendMode.dstIn);
  });

  testWidgets('with Reduce Motion the shimmer leaves the text untouched', (tester) async {
    await tester.pumpWidget(host(reduce: true));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.text('Generando'), findsOneWidget);
  });
}
