/// Configuración por entorno. Podés pasar un archivo local `env.json`
/// (copiado desde `env.example.json`, ignorado por Git) o `--dart-define`:
///
/// ```
/// flutter run -d chrome --dart-define-from-file=env.json
/// flutter run -d chrome \
///   --dart-define=SUPABASE_URL=https://TU-PROYECTO.supabase.co \
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=TU_PUBLISHABLE_KEY
/// flutter run -d chrome --dart-define=USE_MOCK=true   # demo sin internet
/// ```
///
/// `SUPABASE_ANON_KEY` sigue funcionando como nombre alternativo (clave legacy).
/// Nunca commitear `env.json` ni claves, ni usar `service_role` en la app.
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const String _legacyAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// Clave pública del proyecto (publishable key, o la anon key legacy).
  static String get supabaseKey =>
      _publishableKey.isNotEmpty ? _publishableKey : _legacyAnonKey;

  /// Fuerza el modo demo con datos en memoria.
  static const bool useMock = bool.fromEnvironment('USE_MOCK');

  static bool get hasSupabaseCredentials =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Si faltan credenciales se cae al modo mock, así la app y los tests
  /// siguen funcionando sin configuración.
  static bool get shouldUseMock => useMock || !hasSupabaseCredentials;
}
