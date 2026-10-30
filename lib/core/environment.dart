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
