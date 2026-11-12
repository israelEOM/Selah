/// Build-time configuration, passed with `--dart-define-from-file=config/beta.json`.
class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.supabaseAnonKey});

  factory AppConfig.fromEnvironment() => const AppConfig(
        supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
        supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
      );

  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get hasBackend => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

/// While Selah is tested with one church, the app shows only this one (ICP Alcorcón): no church list, no
/// switching, no joining or bringing another. Build with `--dart-define=PILOT_CHURCH=` to open it to every church.
/// Tests start with it empty (see test/flutter_test_config.dart) and set it where they check the pilot.
String pilotChurchSlug = const String.fromEnvironment('PILOT_CHURCH', defaultValue: 'selah');

/// Whether the app is pinned to [pilotChurchSlug].
bool get singleChurch => pilotChurchSlug.isNotEmpty;
