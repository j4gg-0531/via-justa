import 'package:via_justa/features/onboarding/domain/profile_type.dart';

/// Perfil del usuario tal como vive en `public.profiles`.
///
/// Entidad de dominio: no contiene JSON, ni `BuildContext`, ni tipos de
/// Supabase. La conversión desde la fila de la base de datos ocurre en `data/`.
class UserProfile {
  const UserProfile({
    required this.id,
    this.displayName,
    this.language = 'es',
    this.profileType,
    this.originCountry,
    this.currentMunicipalityCode,
  });

  final String id;
  final String? displayName;

  /// Idioma preferido guardado en el servidor: `es` o `en`.
  final String language;
  final ProfileType? profileType;
  final String? originCountry;
  final String? currentMunicipalityCode;

  UserProfile copyWith({
    String? displayName,
    String? language,
    ProfileType? profileType,
    String? originCountry,
    String? currentMunicipalityCode,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      language: language ?? this.language,
      profileType: profileType ?? this.profileType,
      originCountry: originCountry ?? this.originCountry,
      currentMunicipalityCode:
          currentMunicipalityCode ?? this.currentMunicipalityCode,
    );
  }
}
