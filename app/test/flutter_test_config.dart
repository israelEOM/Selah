import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Loads Source Serif 4 so layout tests measure the real serif instead of the placeholder font.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final loader = FontLoader('Source Serif 4');
  for (final face in ['Regular', 'It', 'Semibold', 'SemiboldIt', 'Bold']) {
    final bytes = File('assets/fonts/SourceSerif4-$face.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
  await testMain();
}
