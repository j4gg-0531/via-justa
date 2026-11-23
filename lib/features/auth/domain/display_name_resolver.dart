/// Reglas puras para resolver el nombre visible inicial de una cuenta (Dart puro).
library;

/// Resuelve el nombre visible inicial priorizando metadatos explícitos sobre el prefijo del correo.
String? resolveInitialDisplayName({
  String? explicitDisplayName,
  String? fullName,
  String? metadataName,
  String? email,
}) {
  for (final candidate in [explicitDisplayName, fullName, metadataName]) {
    final trimmed = candidate?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return extractEmailPrefix(email);
}

/// Devuelve el nombre real entregado por el proveedor OAuth cuando el perfil aún está vacío o tiene solo el prefijo del correo.
String? resolvePreferredGoogleDisplayName({
  required String? currentDisplayName,
  required String? oauthDisplayName,
  required String? email,
}) {
  final preferred = oauthDisplayName?.trim() ?? '';
  if (preferred.isEmpty) return null;

  final emailPrefix = extractEmailPrefix(email);
  if (emailPrefix != null &&
      preferred.toLowerCase() == emailPrefix.toLowerCase()) {
    return null;
  }

  final current = currentDisplayName?.trim() ?? '';
  if (current.isEmpty) {
    return preferred;
  }

  if (emailPrefix != null &&
      current.toLowerCase() == emailPrefix.toLowerCase()) {
    return preferred;
  }

  return null;
}

/// Extrae el segmento anterior a `@` de un correo electrónico, o `null` si no aplica.
String? extractEmailPrefix(String? email) {
  final trimmed = email?.trim() ?? '';
  final atIndex = trimmed.indexOf('@');
  if (atIndex <= 0) return null;
  final prefix = trimmed.substring(0, atIndex).trim();
  return prefix.isEmpty ? null : prefix;
}
