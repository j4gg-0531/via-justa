import 'package:via_justa/features/auth/domain/user_profile.dart';
import 'package:via_justa/features/onboarding/domain/profile_type.dart';

/// Convierte una fila de `public.profiles` en la entidad de dominio.
///
/// Devuelve `null` si la fila no trae un `id` utilizable (dato corrupto o
/// proyección incompleta). El idioma se normaliza a `es`/`en` porque la columna
/// tiene un CHECK que ya lo garantiza, pero la app no debe romperse con datos
/// inesperados.
UserProfile? profileFromRow(Map<String, dynamic>? row) {
  if (row == null) return null;
  final id = row['id'];
  if (id is! String || id.isEmpty) return null;

  return UserProfile(
    id: id,
    displayName: _text(row['display_name']),
    language: row['language'] == 'en' ? 'en' : 'es',
    profileType: ProfileType.fromWire(row['profile_type']),
    originCountry: _text(row['origin_country']),
    currentMunicipalityCode: _text(row['current_municipality_code']),
  );
}

String? _text(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
