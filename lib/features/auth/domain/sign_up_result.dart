import 'package:via_justa/features/auth/domain/auth_session.dart';

/// Resultado de un registro de cuenta.
///
/// Cuando el proyecto exige confirmar el correo (política D14, aún PENDIENTE),
/// Supabase crea el usuario pero no devuelve sesión: la app debe pedir al
/// usuario que revise su correo en lugar de tratarlo como un error.
class SignUpResult {
  const SignUpResult({this.session, this.confirmationRequired = false});

  final AuthSession? session;
  final bool confirmationRequired;

  bool get isSignedIn => session != null;
}
