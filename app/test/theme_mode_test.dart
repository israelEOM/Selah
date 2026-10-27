import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/src/app/theme_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to system', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  test('reads a saved choice', () {
    final container = ProviderContainer(overrides: [savedThemeModeProvider.overrideWithValue('dark')]);
    addTearDown(container.dispose);
    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  test('ignores junk', () {
    final container = ProviderContainer(overrides: [savedThemeModeProvider.overrideWithValue('blue')]);
    addTearDown(container.dispose);
    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  test('set saves it', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(themeModeProvider.notifier).set(ThemeMode.light);
    expect(container.read(themeModeProvider), ThemeMode.light);
    expect((await SharedPreferences.getInstance()).getString('theme'), 'light');
    expect(await loadSavedThemeMode(), 'light');
  });
}
