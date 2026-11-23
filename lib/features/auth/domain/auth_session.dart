/// Sesión autenticada mínima que la app necesita conocer.
///
/// No expone tokens ni objetos de Supabase: solo el identificador y el correo
/// que se muestran en la interfaz.
class AuthSession {
  const AuthSession({
    required this.userId,
    this.email,
    this.isExternalProvider = false,
    this.suggestedDisplayName,
  });

  /// `auth.users.id` del usuario autenticado.
  final String userId;

  /// Correo con el que se registró el usuario (puede ser null si el proveedor
  /// no lo entrega, p. ej. algunos inicios de sesión externos).
  final String? email;

  /// `true` cuando la sesión se originó con un proveedor externo (ej. Google OAuth).
  final bool isExternalProvider;

  /// Nombre sugerido por los metadatos del proveedor al iniciar sesión.
  final String? suggestedDisplayName;

  @override
  bool operator ==(Object other) =>
      other is AuthSession &&
      other.userId == userId &&
      other.email == email &&
      other.isExternalProvider == isExternalProvider &&
      other.suggestedDisplayName == suggestedDisplayName;

  @override
  int get hashCode =>
      Object.hash(userId, email, isExternalProvider, suggestedDisplayName);
}
