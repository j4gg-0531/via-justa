/// Sesión autenticada mínima que la app necesita conocer.
///
/// No expone tokens ni objetos de Supabase: solo el identificador y el correo
/// que se muestran en la interfaz.
class AuthSession {
  const AuthSession({required this.userId, this.email});

  /// `auth.users.id` del usuario autenticado.
  final String userId;

  /// Correo con el que se registró el usuario (puede ser null si el proveedor
  /// no lo entrega, p. ej. algunos inicios de sesión externos).
  final String? email;

  @override
  bool operator ==(Object other) =>
      other is AuthSession && other.userId == userId && other.email == email;

  @override
  int get hashCode => Object.hash(userId, email);
}
