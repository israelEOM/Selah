import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The visual family a screen should render in.
enum UiPlatform { ios, android, web }

/// Follows [ThemeData.platform], so `debugDefaultTargetPlatformOverride` works
/// in tests. Web is its own family regardless of the browser's OS.
UiPlatform uiPlatformOf(BuildContext context) {
  if (kIsWeb) return UiPlatform.web;
  return switch (Theme.of(context).platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => UiPlatform.ios,
    _ => UiPlatform.android,
  };
}

/// Kill switch for native Liquid Glass (set false if VoiceOver misbehaves).
const bool kUseNativeGlass = true;

/// True only on a real iOS host, never under a platform override, so tests
/// never build platform views.
bool get nativeGlassAvailable => kUseNativeGlass && !kIsWeb && Platform.isIOS;

bool reduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);
