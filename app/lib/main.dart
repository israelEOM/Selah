import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app/app.dart';
import 'src/app/theme_mode.dart';
import 'src/core/config.dart';
import 'src/data/providers.dart';
import 'src/data/repository.dart';
import 'src/l10n/locale.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  final config = AppConfig.fromEnvironment();
  if (!config.hasBackend) {
    throw StateError('Run with --dart-define-from-file=config/beta.json');
  }
  await Supabase.initialize(url: config.supabaseUrl, publishableKey: config.supabaseAnonKey);
  final savedLanguage = await loadSavedLanguage();
  final savedTheme = await loadSavedThemeMode();
  runApp(ProviderScope(
    overrides: [
      savedLanguageProvider.overrideWithValue(savedLanguage),
      savedThemeModeProvider.overrideWithValue(savedTheme),repositoryProvider.overrideWithValue(SelahRepository(Supabase.instance.client))],
    child: const SelahApp(),
  ));
}
