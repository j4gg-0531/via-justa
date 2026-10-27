/// Errores posibles de validación; la vista los traduce a texto.
enum NameError { empty }

enum EmailError { empty, invalid }

enum PasswordError { empty, tooShort }

/// Largo mínimo de la contraseña (regla local del avance).
const int minPasswordLength = 8;

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

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
