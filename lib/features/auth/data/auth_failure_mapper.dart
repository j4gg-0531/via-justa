import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/features/auth/domain/auth_failure.dart';

/// Traduce cualquier error del cliente de Supabase a un [AuthFailure] de
/// dominio. Mantiene a las pantallas ajenas a GoTrue y a PostgREST.
AuthFailure toAuthFailure(Object error) {
  if (error is AuthFailure) return error;

  // Los fallos de red reintentables heredan de AuthException: se evalúan antes.
  if (error is AuthRetryableFetchException) {
    return const AuthFailure(AuthFailureKind.network);
  }

  if (error is AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return const AuthFailure(AuthFailureKind.invalidCredentials);
      case 'email_not_confirmed':
        return const AuthFailure(AuthFailureKind.emailNotConfirmed);
      case 'user_already_exists':
      case 'email_exists':
        return const AuthFailure(AuthFailureKind.emailAlreadyRegistered);
      case 'weak_password':
        return const AuthFailure(AuthFailureKind.weakPassword);
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
      case 'over_sms_send_rate_limit':
        return const AuthFailure(AuthFailureKind.rateLimited);
    }
    if (error.statusCode == '429') {
      return const AuthFailure(AuthFailureKind.rateLimited);
    }
    // GoTrue usa el estado 0 cuando no pudo contactar al servidor.
    if (error.statusCode == '0') {
      return const AuthFailure(AuthFailureKind.network);
    }
    return const AuthFailure(AuthFailureKind.unknown);
  }

  if (error is PostgrestException) {
    return const AuthFailure(AuthFailureKind.unknown);
  }

  return const AuthFailure(AuthFailureKind.unknown);
}
