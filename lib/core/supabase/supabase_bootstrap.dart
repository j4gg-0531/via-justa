import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/core/supabase/secure_supabase_local_storage.dart';
import 'package:via_justa/core/supabase/supabase_settings.dart';

/// Inicializa el cliente de Supabase si hay configuración compilada válida.
///
/// Controles de seguridad aplicados:
/// - **H-01 (OWASP M9 — Insecure Data Storage):** Persiste tokens de sesión
///   (`access_token` / `refresh_token`) en Android Keystore / iOS Keychain
///   mediante [SecureSupabaseLocalStorage] y flujo OAuth PKCE (`AuthFlowType.pkce`).
/// - **H-03 (OWASP M7/M8 — Fuga de datos en logs):** No imprime objetos de
///   excepción crudos ni trazas en compilaciones de producción (`kReleaseMode`).
Future<SupabaseClient?> initializeSupabase() async {
  final settings = SupabaseSettings.fromEnvironment();
  if (settings == null) return null;

  try {
    final supabase = await Supabase.initialize(
      url: settings.url,
      publishableKey: settings.publishableKey,
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        localStorage: SecureSupabaseLocalStorage(),
      ),
    );
    return supabase.client;
  } catch (_) {
    if (kDebugMode) {
      debugPrint(
        'Supabase no se pudo inicializar; se activa el modo DEMO de respaldo.',
      );
    }
    return null;
  }
}
