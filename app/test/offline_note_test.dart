import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/l10n/app_localizations.dart';
import 'package:selah/src/app/offline_note.dart';
import 'package:selah/src/app/theme.dart';
import 'package:selah/src/data/offline.dart';
import 'package:selah/src/data/providers.dart';

Future<OfflineStatus> _pump(WidgetTester tester, {String locale = 'en'}) async {
  final status = OfflineStatus();
  await tester.pumpWidget(ProviderScope(
    overrides: [offlineStatusProvider.overrideWithValue(status)],
    child: MaterialApp(
      theme: selahLightTheme(),
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: OfflineNote()),
    ),
  ));
  return status;
}

void main() {
  const english = 'Offline. Showing your saved copy.';

  testWidgets('hidden while online', (tester) async {
    await _pump(tester);
    expect(find.text(english), findsNothing);
  });

  testWidgets('appears and goes away', (tester) async {
    final status = await _pump(tester);
    status.fellBack();
    await tester.pump();
    expect(find.text(english), findsOneWidget);
    status.reached();
    await tester.pump();
    expect(find.text(english), findsNothing);
  });

  testWidgets('spanish copy', (tester) async {
    final status = await _pump(tester, locale: 'es');
    status.fellBack();
    await tester.pump();
    expect(find.text('Sin conexión. Estás viendo tu copia guardada.'), findsOneWidget);
  });

  testWidgets('portuguese copy', (tester) async {
    final status = await _pump(tester, locale: 'pt');
    status.fellBack();
    await tester.pump();
    expect(find.text('Sem conexão. Você está vendo sua cópia salva.'), findsOneWidget);
  });
}
