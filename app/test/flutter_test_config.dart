import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the bundled serif so layout tests measure a real serif instead of the placeholder font. Tests have no
/// Georgia, the app's serif on Apple devices, so the same faces stand in under that name too.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  for (final family in ['Source Serif 4', 'Georgia']) {
    final loader = FontLoader(family);
    for (final face in ['Regular', 'It', 'Semibold', 'SemiboldIt', 'Bold']) {
      final bytes = File('assets/fonts/SourceSerif4-$face.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
  await testMain();
}
