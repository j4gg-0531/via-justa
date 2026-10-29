import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cliente de Supabase disponible en la app.
///
/// `main.dart` lo sobreescribe con el cliente real cuando hay configuración
/// compilada. Por defecto es `null`, lo que mantiene el modo DEMO y permite
/// ejecutar las pruebas sin red ni credenciales.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);
