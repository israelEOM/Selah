import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _preferenceKey = 'theme';

/// The theme choice saved before the app started; `main` overrides this once.
final savedThemeModeProvider = Provider<String?>((ref) => null);

final themeModeProvider = NotifierProvider<AppThemeMode, ThemeMode>(AppThemeMode.new);

/// Follows the phone's light or dark setting until the member picks one.
class AppThemeMode extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final saved = ref.watch(savedThemeModeProvider);
    return ThemeMode.values.where((m) => m.name == saved).firstOrNull ?? ThemeMode.system;
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferenceKey, mode.name);
  }
}

Future<String?> loadSavedThemeMode() async => (await SharedPreferences.getInstance()).getString(_preferenceKey);
