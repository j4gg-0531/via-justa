/// Motivos de fallo de autenticación, independientes del proveedor.
///
/// La capa de datos traduce los errores de Supabase a este enum y la vista los
/// convierte a texto con `'auth.error.*'.tr()`. Así ninguna pantalla conoce
/// detalles de GoTrue ni de la red.
enum AuthFailureKind {
  /// El correo o la contraseña no coinciden con una cuenta existente.
  invalidCredentials,

  /// Ya existe una cuenta con ese correo.
  emailAlreadyRegistered,

  /// La cuenta existe pero falta confirmar el correo (D14 pendiente).
  emailNotConfirmed,

  /// La contraseña no cumple la política del servidor.
  weakPassword,

  /// Demasiados intentos en poco tiempo.
  rateLimited,

  /// Sin conexión o el servidor no respondió.
  network,

  /// El registro se completó pero Supabase exige confirmar el correo antes de
  /// iniciar sesión. No es un error del usuario.
  emailConfirmationRequired,

  /// El servidor rechazó guardar un tipo de perfil que aún no está habilitado
  /// (D11: `resident` sigue PROPUESTA).
  profileTypeNotSupported,

  /// Cualquier otro fallo no clasificado.
  unknown,
}

/// Fallo de autenticación tipado que viaja desde `data/` hasta la vista.
class AuthFailure implements Exception {
  const AuthFailure(this.kind);

  final AuthFailureKind kind;

  @override
  String toString() => 'AuthFailure(${kind.name})';
}
