/// Tipo de perfil que el usuario selecciona en el onboarding.
///
/// `resident` sigue PROPUESTA en `docs/decisiones.md` (D11): el CHECK de
/// `public.profiles.profile_type` solo admite `visitor` y `settler`, por lo que
/// el repositorio rechaza guardarlo en el servidor y la app lo conserva local.
enum ProfileType {
  /// Visitante / Turista
  visitor('visitor'),

  /// Instalación / Migrante
  settler('settler'),

  /// Local / Residente
  resident('resident');

  const ProfileType(this.wireValue);

  /// Valor que viaja a la base de datos.
  final String wireValue;

  /// Convierte el valor textual de `public.profiles.profile_type`.
  /// Devuelve `null` si el servidor envía un valor desconocido.
  static ProfileType? fromWire(Object? raw) {
    if (raw is! String) return null;
    for (final type in ProfileType.values) {
      if (type.wireValue == raw) return type;
    }
    return null;
  }

  /// Tipos que el backend acepta (D11 ratificada en migración 0006: visitor, settler y resident).
  bool get isPersistable => true;
}
