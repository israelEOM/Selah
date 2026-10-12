import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app/app.dart';
import 'src/core/config.dart';
import 'src/data/providers.dart';
import 'src/data/repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  final config = AppConfig.fromEnvironment();
  if (!config.hasBackend) {
    throw StateError('Run with --dart-define-from-file=config/beta.json');
  }
  await Supabase.initialize(url: config.supabaseUrl, publishableKey: config.supabaseAnonKey);
  runApp(ProviderScope(
    overrides: [repositoryProvider.overrideWithValue(SelahRepository(Supabase.instance.client))],
    child: const SelahApp(),
  ));
}
