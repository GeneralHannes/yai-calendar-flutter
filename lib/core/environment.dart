/// Compile-time configuration. Values are baked in by the compiler, so they
/// cost nothing at runtime and dead branches are tree-shaken.
///
///   flutter run --dart-define=API_BASE_URL=https://staging.api.example.com
class Environment {
  const Environment._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.yourdomain.com',
  );
}

/// Shared-calendar backend (Supabase). Both are public values: access is
/// limited by row level security and the calendar code, not by hiding these.
///
///   flutter build web --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ...
class SharedConfig {
  const SharedConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get configured => url.isNotEmpty && anonKey.isNotEmpty;
}
