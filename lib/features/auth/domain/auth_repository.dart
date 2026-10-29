import 'package:via_justa/features/auth/domain/auth_session.dart';
import 'package:via_justa/features/auth/domain/consent_document.dart';
import 'package:via_justa/features/auth/domain/sign_up_result.dart';
import 'package:via_justa/features/auth/domain/user_profile.dart';
import 'package:via_justa/features/onboarding/domain/profile_type.dart';

/// Contrato de autenticación y perfil.
///
/// Solo la implementación concreta (Supabase o DEMO) conoce la red y el
/// almacenamiento. Cambiar de proveedor no debe tocar ninguna pantalla.
abstract class AuthRepository {
  /// `true` cuando no hay backend configurado y los datos son de ejemplo.
  /// La interfaz debe rotularlo como DEMO.
  bool get usesDemoData;

  /// Emite la sesión actual al suscribirse y cada vez que cambia.
  Stream<AuthSession?> watchSession();

  /// Sesión vigente (restaurada desde el almacenamiento del dispositivo).
  Future<AuthSession?> currentSession();

  /// Inicia sesión con correo y contraseña.
  Future<AuthSession> signIn({
    required String email,
    required String password,
  });

  /// Crea la cuenta. Puede no devolver sesión si el proyecto exige confirmar
  /// el correo.
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  /// Cierra la sesión en el dispositivo (y en el servidor si aplica).
  Future<void> signOut();

  /// Perfil del usuario o `null` si todavía no existe la fila.
  Future<UserProfile?> fetchProfile(String userId);

  /// Guarda el nombre visible en `public.profiles.display_name`.
  Future<void> saveDisplayName(String userId, String displayName);

  /// Guarda el idioma preferido (`es` / `en`).
  Future<void> saveLanguage(String userId, String language);

  /// Guarda el tipo de perfil. `resident` puede no estar habilitado (D11).
  Future<void> saveProfileType(String userId, ProfileType type);

  /// Registra la aceptación de los documentos legales.
  Future<void> registerConsents({
    required String userId,
    required List<ConsentDocType> documents,
    required String version,
  });
}
