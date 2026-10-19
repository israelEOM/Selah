import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const supportedLanguages = ['es', 'en', 'pt'];

const _preferenceKey = 'language';

/// The device's language when the app supports it, Spanish otherwise.
String languageFor(Locale device) =>
    supportedLanguages.contains(device.languageCode)
    ? device.languageCode
    : 'es';

/// The language saved before the app started; `main` overrides this once.
final savedLanguageProvider = Provider<String?>((ref) => null);

final appLocaleProvider = NotifierProvider<AppLocale, Locale>(AppLocale.new);

class AppLocale extends Notifier<Locale> {
  @override
  Locale build() {
    final saved = ref.watch(savedLanguageProvider);
    if (saved != null && supportedLanguages.contains(saved)) {
      return Locale(saved);
    }
    return Locale(languageFor(PlatformDispatcher.instance.locale));
  }

  Future<void> set(String language) async {
    if (!supportedLanguages.contains(language)) return;
    state = Locale(language);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferenceKey, language);
  }
}

Future<String?> loadSavedLanguage() async =>
    (await SharedPreferences.getInstance()).getString(_preferenceKey);
