/// Categoría principal de elementos visibles en el mapa local del municipio (M08).
enum PriceMapCategory {
  /// Reportes comunitarios de precios con semáforo
  prices,

  /// Servicios locales y de salud (hospitales, clínicas, comercios)
  services,

  /// Puntos de orientación migratoria y consulados
  consulates,
}

/// Estado visual del marcador en el mapa local.
enum PricePinStatus {
  /// Precio dentro del rango de referencia (semáforo verde)
  fair,

  /// Precio moderadamente por encima de la referencia (semáforo ámbar)
  moderate,

  /// Precio con sobrecobro significativo (semáforo rojo)
  alert,

  /// Punto informativo de servicio o institución (sin semáforo de precio)
  info,
}

/// Tipo semántico de ícono para el marcador y la tarjeta del mapa local.
enum PriceMapPinKind {
  food,
  transport,
  lodging,
  hospital,
  assistance,
  consulate,
}

/// Entidad inmutable que representa un marcador de precio o servicio en el mapa del municipio (M08).
class PriceMapItem {
  const PriceMapItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.pinKind,
    required this.status,
    required this.pinLabel,
    required this.badgeText,
    required this.normalizedX,
    required this.normalizedY,
    required this.municipalityCode,
    this.isDemo = true,
  });

  final String id;

  /// Nombre del punto, servicio o referencia de precio.
  final String name;

  /// Descripción corta del servicio o contexto del precio de referencia.
  final String description;

  final PriceMapCategory category;
  final PriceMapPinKind pinKind;
  final PricePinStatus status;

  /// Texto corto que se muestra en el globo del marcador (ej. "$12k", "$45k" o vacío si es solo ícono).
  final String pinLabel;

  /// Etiqueta de distancia o precio para la tarjeta inferior (ej. "2.4 km" o "$12.000").
  final String badgeText;

  /// Posición horizontal relativa (0.0 a 1.0) en el lienzo del mapa DEMO.
  final double normalizedX;

  /// Posición vertical relativa (0.0 a 1.0) en el lienzo del mapa DEMO.
  final double normalizedY;

  /// Código DIVIPOLA del municipio al que pertenece el punto.
  final String municipalityCode;

  /// Indica si el registro corresponde a un dato demostrativo (DEMO).
  final bool isDemo;

  /// Coordenada horizontal en rango de alineación [-1.0, 1.0].
  double get alignmentX => (normalizedX * 2) - 1;

  /// Coordenada vertical en rango de alineación [-1.0, 1.0].
  double get alignmentY => (normalizedY * 2) - 1;
}
