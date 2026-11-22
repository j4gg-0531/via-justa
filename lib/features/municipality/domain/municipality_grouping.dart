import 'package:via_justa/features/municipality/domain/municipality.dart';

/// Partición determinística de municipios entre activos en el piloto y próximos.
class MunicipalityListPartition {
  const MunicipalityListPartition({
    required this.pilot,
    required this.upcoming,
  });

  final List<Municipality> pilot;
  final List<Municipality> upcoming;

  bool get isEmpty => pilot.isEmpty && upcoming.isEmpty;
  int get totalCount => pilot.length + upcoming.length;
}

/// Separa los municipios piloto de los no piloto preservando el orden original
/// de cada grupo (regla pura de dominio para evitar filtros en la vista).
MunicipalityListPartition partitionMunicipalities(
  List<Municipality> municipalities,
) {
  final pilot = <Municipality>[];
  final upcoming = <Municipality>[];
  for (final municipality in municipalities) {
    if (municipality.isPilot) {
      pilot.add(municipality);
    } else {
      upcoming.add(municipality);
    }
  }
  return MunicipalityListPartition(
    pilot: List<Municipality>.unmodifiable(pilot),
    upcoming: List<Municipality>.unmodifiable(upcoming),
  );
}

/// Acota un índice de carrusel dentro de los límites válidos `[0, length - 1]`.
int clampGalleryIndex(int index, int length) {
  if (length <= 0) return 0;
  if (index < 0) return 0;
  if (index >= length) return length - 1;
  return index;
}
