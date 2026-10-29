/// Configuración del backend Supabase leída en tiempo de compilación.
///
/// Los valores se inyectan con `--dart-define` y nunca se versionan:
///
/// ```powershell
/// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// ```
///
/// Si faltan ambos, la app arranca en modo DEMO (ver `.env.example`).
class SupabaseSettings {
  const SupabaseSettings({required this.url, required this.publishableKey});

  static const String _url = String.fromEnvironment('SUPABASE_URL');
  static const String _publishableKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  final String url;

  /// Clave pública (`anon` / `publishable`). Nunca la `service_role`.
  final String publishableKey;

  bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  /// Configuración válida o `null` si el proyecto no se compiló con secretos.
  static SupabaseSettings? fromEnvironment() {
    const settings = SupabaseSettings(
      url: _url,
      publishableKey: _publishableKey,
    );
    return settings.isConfigured ? settings : null;
  }
}
