/// Configuración del backend Supabase leída en tiempo de compilación.
///
/// Los valores se inyectan con `--dart-define` y nunca se versionan:
///
/// ```powershell
/// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// ```
///
/// Controles de seguridad (OWASP M1 / M5):
/// - Rechaza URLs en texto claro (`http://`) o malformadas; exige `https://`.
/// - Rechaza claves privadas de servidor (`service_role`, `sb_secret_`, `sbp_`).
class SupabaseSettings {
  const SupabaseSettings({required this.url, required this.publishableKey});

  static const String _url = String.fromEnvironment('SUPABASE_URL');
  static const String _publishableKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  final String url;

  /// Clave pública (`anon` / `publishable`). Nunca la `service_role`.
  final String publishableKey;

  /// Verifica que el endpoint utilice exclusivamente HTTPS con un host válido (OWASP M5).
  bool get isValidHttpsEndpoint {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null) return false;
    return parsed.scheme == 'https' &&
        parsed.host.isNotEmpty &&
        !parsed.host.contains(' ') &&
        parsed.userInfo.isEmpty;
  }

  /// Verifica que la clave inyectada sea pública y nunca una llave maestra de servidor (OWASP M1).
  bool get isSafePublishableKey {
    final trimmed = publishableKey.trim();
    if (trimmed.isEmpty) return false;
    final lower = trimmed.toLowerCase();
    if (lower.contains('service_role') ||
        lower.startsWith('sb_secret_') ||
        lower.startsWith('sbp_')) {
      return false;
    }
    return true;
  }

  bool get isConfigured => isValidHttpsEndpoint && isSafePublishableKey;

  /// Configuración válida o `null` si el proyecto no se compiló con credenciales seguras.
  static SupabaseSettings? fromEnvironment() {
    const settings = SupabaseSettings(
      url: _url,
      publishableKey: _publishableKey,
    );
    return settings.isConfigured ? settings : null;
  }
}
