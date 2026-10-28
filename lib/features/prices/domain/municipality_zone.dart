/// Estado del permiso de ubicación para la autodetección de la zona del municipio.
enum LocationPermissionStatus {
  /// Aún no se ha respondido la solicitud de permiso de ubicación.
  prompt,

  /// El usuario permitió el acceso a la ubicación del teléfono (detección automática por GPS).
  granted,

  /// El usuario denegó el permiso de ubicación (selección manual en el mapa local).
  denied,
}

/// Zona geográfica dentro de un municipio para segmentar las medianas estadísticas de precios.
/// Por ejemplo, en el piloto de Valledupar (`20001`): Zona Norte, Zona Centro, Zona Sur, Zona Oriente y Zona Occidente.
class MunicipalityZone {
  const MunicipalityZone({
    required this.id,
    required this.municipalityCode,
    required this.nameEs,
    required this.nameEn,
    required this.sectorHintEs,
    required this.sectorHintEn,
    this.normalizedX = 0.5,
    this.normalizedY = 0.5,
    this.sortOrder = 0,
  });

  /// Identificador único de la zona (ej. `vup_norte`, `vup_centro`, `vup_sur`).
  final String id;

  /// Código DIVIPOLA del municipio al que pertenece la zona (ej. `'20001'` para Valledupar).
  final String municipalityCode;

  /// Nombre de la zona en español (ej. `"Zona Norte"`).
  final String nameEs;

  /// Nombre de la zona en inglés (ej. `"North Zone"`).
  final String nameEn;

  /// Barrios o sectores de referencia en español (ej. `"Novalito, San Joaquín, CC Guatapurí"`).
  final String sectorHintEs;

  /// Barrios o sectores de referencia en inglés (ej. `"Novalito, San Joaquín, Guatapurí Mall"`).
  final String sectorHintEn;

  /// Coordenada horizontal normalizada [0.0, 1.0] en el lienzo del mapa del municipio.
  final double normalizedX;

  /// Coordenada vertical normalizada [0.0, 1.0] en el lienzo del mapa del municipio.
  final double normalizedY;

  /// Orden de visualización.
  final int sortOrder;

  /// Coordenada horizontal en rango de alineación [-1.0, 1.0] para posicionar en el mapa sin cálculos en la vista.
  double get alignmentX => (normalizedX * 2) - 1;

  /// Coordenada vertical en rango de alineación [-1.0, 1.0] para posicionar en el mapa sin cálculos en la vista.
  double get alignmentY => (normalizedY * 2) - 1;

  /// Retorna el nombre de la zona según el idioma activo (`es` o `en`).
  String localizedName(String languageCode) {
    return languageCode.toLowerCase().startsWith('en') ? nameEn : nameEs;
  }

  /// Retorna los barrios o puntos de referencia según el idioma activo (`es` o `en`).
  String localizedSectorHint(String languageCode) {
    return languageCode.toLowerCase().startsWith('en')
        ? sectorHintEn
        : sectorHintEs;
  }

  /// Retorna una etiqueta combinada de nombre y sectores de referencia.
  String localizedFullLabel(String languageCode) {
    final name = localizedName(languageCode);
    final hint = localizedSectorHint(languageCode);
    return hint.isEmpty ? name : '$name ($hint)';
  }

  factory MunicipalityZone.fromMap(Map<String, dynamic> map) {
    return MunicipalityZone(
      id: map['id'] as String,
      municipalityCode: map['municipality_code'] as String,
      nameEs: map['name_es'] as String,
      nameEn: map['name_en'] as String,
      sectorHintEs: map['sector_hint_es'] as String? ?? '',
      sectorHintEn: map['sector_hint_en'] as String? ?? '',
      normalizedX: (map['normalized_x'] as num?)?.toDouble() ?? 0.5,
      normalizedY: (map['normalized_y'] as num?)?.toDouble() ?? 0.5,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }
}

/// Función pura de dominio que determina la zona del municipio más cercana
/// a un punto normalizado `(normalizedX, normalizedY)` tocado en el mapa.
MunicipalityZone? resolveNearestZoneByNormalizedPoint({
  required List<MunicipalityZone> zones,
  required double normalizedX,
  required double normalizedY,
}) {
  if (zones.isEmpty) return null;

  final clampedX = normalizedX.clamp(0.0, 1.0);
  final clampedY = normalizedY.clamp(0.0, 1.0);

  MunicipalityZone nearest = zones.first;
  double minDistanceSquared = double.infinity;

  for (final zone in zones) {
    final dx = zone.normalizedX - clampedX;
    final dy = zone.normalizedY - clampedY;
    final distanceSquared = (dx * dx) + (dy * dy);
    if (distanceSquared < minDistanceSquared) {
      minDistanceSquared = distanceSquared;
      nearest = zone;
    }
  }

  return nearest;
}
