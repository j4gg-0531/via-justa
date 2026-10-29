import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/core/supabase/supabase_settings.dart';

/// Inicializa el cliente de Supabase si hay configuración compilada.
///
/// Devuelve `null` cuando no hay `SUPABASE_URL`/`SUPABASE_ANON_KEY` o cuando la
/// inicialización falla: en ese caso la app continúa en modo DEMO en lugar de
/// cerrarse al arrancar.
Future<SupabaseClient?> initializeSupabase() async {
  final settings = SupabaseSettings.fromEnvironment();
  if (settings == null) return null;

  try {
    final supabase = await Supabase.initialize(
      url: settings.url,
      publishableKey: settings.publishableKey,
    );
    return supabase.client;
  } catch (error) {
    debugPrint('Supabase no se pudo inicializar; se usa el modo DEMO: $error');
    return null;
  }
}
