/// Errores posibles de validación; la vista los traduce a texto.
enum NameError { empty }

enum EmailError { empty, invalid }

enum PasswordError { empty, tooShort }

enum ConfirmPasswordError { empty, mismatch }

enum OtpCodeError { empty, invalid, expiredLink }

/// Tipo de credencial de recuperación extraída de la entrada del usuario.
enum RecoveryCredentialKind {
  /// Código numérico de 6 a 8 dígitos (`123456`).
  otpCode,

  /// Hash de token extraído de un enlace `/auth/v1/verify?token=...` o pegado directamente.
  tokenHash,

  /// URL de redirección con `#access_token=...` o `?code=...`.
  redirectSessionUrl,
}

/// Credencial de recuperación ya clasificada y normalizada.
class ParsedRecoveryCredential {
  const ParsedRecoveryCredential({
    required this.kind,
    required this.value,
  });

  final RecoveryCredentialKind kind;
  final String value;
}

/// Largo mínimo de la contraseña (regla local del avance).
const int minPasswordLength = 8;

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final RegExp _otpCodePattern = RegExp(r'^\d{6,8}$');
final RegExp _tokenHashPattern = RegExp(r'^(pkce_)?[A-Za-z0-9_-]{16,256}$');

NameError? validateName(String value) =>
    value.trim().isEmpty ? NameError.empty : null;

EmailError? validateEmail(String value) {
  final email = value.trim();
  if (email.isEmpty) return EmailError.empty;
  if (!_emailPattern.hasMatch(email)) return EmailError.invalid;
  return null;
}

/// La contraseña no se recorta: los espacios cuentan como caracteres.
PasswordError? validatePassword(String value) {
  if (value.isEmpty) return PasswordError.empty;
  if (value.length < minPasswordLength) return PasswordError.tooShort;
  return null;
}

/// Verifica que la confirmación no esté vacía y coincida con la contraseña.
ConfirmPasswordError? validateConfirmPassword({
  required String password,
  required String confirmPassword,
}) {
  if (confirmPassword.isEmpty) return ConfirmPasswordError.empty;
  if (confirmPassword != password) return ConfirmPasswordError.mismatch;
  return null;
}

/// Analiza la entrada de recuperación: acepta un código numérico de 6–8 dígitos,
/// el enlace del botón "Reset password" del correo (`/auth/v1/verify?token=...`),
/// una URL redirigida con `#access_token=` / `?code=`, o el `token_hash` directo.
ParsedRecoveryCredential? parseRecoveryCredential(String rawValue) {
  final trimmed = rawValue.trim();
  if (trimmed.isEmpty) return null;

  if (_otpCodePattern.hasMatch(trimmed)) {
    return ParsedRecoveryCredential(
      kind: RecoveryCredentialKind.otpCode,
      value: trimmed,
    );
  }

  final uri = Uri.tryParse(trimmed);
  if (uri != null && (uri.hasScheme || trimmed.contains('token='))) {
    final tokenParam =
        uri.queryParameters['token'] ?? uri.queryParameters['token_hash'];
    if (tokenParam != null && tokenParam.trim().isNotEmpty) {
      return ParsedRecoveryCredential(
        kind: RecoveryCredentialKind.tokenHash,
        value: tokenParam.trim(),
      );
    }
    if (trimmed.contains('access_token=') ||
        uri.queryParameters.containsKey('code')) {
      return ParsedRecoveryCredential(
        kind: RecoveryCredentialKind.redirectSessionUrl,
        value: trimmed,
      );
    }
  }

  if (_tokenHashPattern.hasMatch(trimmed)) {
    return ParsedRecoveryCredential(
      kind: RecoveryCredentialKind.tokenHash,
      value: trimmed,
    );
  }

  return null;
}

/// Valida el código OTP o enlace de recuperación pegado desde el correo de Supabase.
OtpCodeError? validateOtpCode(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return OtpCodeError.empty;
  if (trimmed.contains('error=access_denied') ||
      trimmed.contains('otp_expired')) {
    return OtpCodeError.expiredLink;
  }
  if (parseRecoveryCredential(trimmed) == null) {
    return OtpCodeError.invalid;
  }
  return null;
}
